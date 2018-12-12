$VERBOSE = nil  # Don't care about world writable dir warnings and the like

require 'pathname'
require 'fileutils'

class OrigenBootError < StandardError
end

# Keep a note of the pwd at the time when Origen was first loaded, this is initially used
# by the site_config lookup.
$_origen_invocation_pwd ||= Pathname.pwd

# This will be referenced later in ruby_version_check, the origen used to launch
# the process is different than the one that actually runs under bundler
$origen_launch_root = Pathname.new(File.dirname(__FILE__)).parent

# Override any influence from $LANG in the users environment
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
ENV['LC_ALL'] = nil
ENV['LANG'] = nil
ENV['LANG'] = 'en_US.UTF-8'

load File.expand_path('../operating_systems.rb', __FILE__)

# Are we inside an Origen application workspace?
# If ORIGEN_ROOT is defined it means that we were launched within an app from the new style Origen binstub,
# so all is well
if defined?(ORIGEN_ROOT)
  origen_root = ORIGEN_ROOT
else
  app_config = File.join('config', 'application.rb')
  if File.exist?(app_config)
    origen_root = Dir.pwd
  else
    path = Pathname.new(Dir.pwd)
    until path.root? || origen_root
      if File.exist?(File.join(path, app_config))
        origen_root = path.to_s
      else
        path = path.parent
      end
    end
  end
  # If we are in an app and we have not been invoked through a Bundler binstub, then check if one exists and
  # if so re-launch through it, otherwise create one and then re-launch through that
  if origen_root && !ENV['BUNDLE_BIN_PATH']
    binstub = File.join(origen_root, 'lbin', 'origen')
    unless File.exist?(binstub)
      require_relative 'boot/app'
      Origen::Boot.create_origen_binstub(origen_root)
    end
    exec Gem.ruby, binstub, *ARGV
  end
end

# Defer loading this until we have re-launched above to save time
load File.expand_path('../site_config.rb', __FILE__)

warnings = nil

########################################################################################################################
########################################################################################################################
## If running inside an application workspace
########################################################################################################################
########################################################################################################################
if origen_root
  require_relative 'boot/app'

  if ARGV.first == 'setup'
    Origen::Boot.setup(origen_root)
    puts
    puts 'Your application has been setup successfully'
    exit 0
  else
    warnings = Origen::Boot.app!(origen_root)
    boot_app = true
  end

########################################################################################################################
########################################################################################################################
## If running outside an application and a user or central tool Origen bundle is to be used
##
## Note that there is a lot of duplication of the above code, however this is a copy of the original code
## to boot up outside an app when a tool Origen bundle is present. It has been maintained separately to
## ensure that the changes to how an application boots up do not affect the global tool installation functionality.
########################################################################################################################
########################################################################################################################
elsif Origen.site_config.gem_manage_bundler && (Origen.site_config.user_install_enable || Origen.site_config.tool_repo_install_dir)
  # Force everyone to have a consistent way of installing gems with bundler.
  # In this case, we aren't running from an Origen application, so build everything at Origen.home instead
  # Have two options here: if user_install_enable is true, use user_install_dir. Otherwise, use the tool_repo_install_dir
  install_dir = Origen.site_config.user_install_enable ? File.expand_path(Origen.site_config.user_install_dir) : File.expand_path(Origen.site_config.tool_repo_install_dir)
  unless Dir.exist?(install_dir)
    load File.expand_path('../../lib/origen/utility/input_capture.rb', __FILE__)
    include Origen::Utility::InputCapture

    puts "Root directory '#{install_dir}' does not exist. Would you like to create it?"
    if get_text(confirm: :return_boolean)
      FileUtils.mkdir(install_dir)
    else
      puts 'Exiting with creating Origen install'
      exit!
    end
  end

  gemfile = File.join(install_dir, 'Gemfile')
  unless File.exist?(gemfile)
    # Create a default Gemfile that can be further customized by the user.
    # Initial Gemfile only requires Origen. Nothing else. Essentially a blank installation.
    Dir.chdir(install_dir) do
      `bundle init`
    end
    # The above will give a general Gemfile from Bundler. We'll just append "gem 'origen' to the end.
    File.open(gemfile, 'a') do |f|
      f << "gem 'origen'\n"
    end
  end
  ENV['BUNDLE_GEMFILE'] = gemfile
  ENV['BUNDLE_PATH'] = File.expand_path(Origen.site_config.gem_install_dir)
  ENV['BUNDLE_BIN'] = File.join(install_dir, 'lbin')

  origen_exec = File.join(ENV['BUNDLE_BIN'], 'origen')

  # If the user/tool bundle already exists but we have not been invoked through that, abort this thread
  # and re-launch under the required bundler environment
  if File.exist?(origen_exec) && !ENV['BUNDLE_BIN_PATH'] && File.exist?(ENV['BUNDLE_PATH'])
    exec Gem.ruby, origen_exec, *ARGV
    exit 0
  else
    boot_app = false
  end

  if File.exist?(ENV['BUNDLE_GEMFILE'])
    # Overriding bundler here so that bundle install can be automated as required
    require 'bundler/shared_helpers'
    if Bundler::SharedHelpers.in_bundle?
      require 'bundler'
      if STDOUT.tty?
        begin
          fail OrigenBootError unless File.exist?(ENV['BUNDLE_BIN'])
          Bundler.setup
          fail OrigenBootError unless File.exist?(ENV['BUNDLE_BIN'])
        rescue Gem::LoadError, Bundler::BundlerError, OrigenBootError => e
          cmd = "bundle install --gemfile #{ENV['BUNDLE_GEMFILE']} --binstubs #{ENV['BUNDLE_BIN']} --path #{ENV['BUNDLE_PATH']}"
          # puts cmd
          puts 'Installing required gems...'
          puts
          `chmod o-w #{install_dir}` # Stops some annoying world writable warnings during install
          `chmod o-w #{install_dir}/bin` if File.exist?("#{install_dir}/bin")
          `chmod o-w #{install_dir}/.bin` if File.exist?("#{install_dir}/.bin")
          result = false

          Bundler.with_clean_env do
            if Origen.os.unix?
              if Origen.site_config.gem_build_switches
                Origen.site_config.gem_build_switches.each do |switches|
                  `bundle config build.#{switches}`
                end
              end
            end
            result = system(cmd)
          end
          `chmod o-w #{ENV['BUNDLE_BIN']}`
          # Make .bat versions of all executables, Bundler should really be doing this when running
          # on windows
          if Origen.os.windows?
            bat_present = File.exist? "#{install_dir}/lbin/origen.bat"
            Dir.glob("#{install_dir}/lbin/*").each do |bin|
              unless bin =~ /.bat$/
                bat = "#{bin}.bat"
                unless File.exist?(bat)
                  File.open(bat, 'w') { |f| f.write('@"ruby.exe" "%~dpn0" %*') }
                end
              end
            end
            if !bat_present && !result
              puts 'Some Windows specific updates to your workspace were required, please re-run the last command'
              exit 0
            end
          end
          if result
            exec "origen #{ARGV.join(' ')}"
            exit 0
          else
            puts
            puts "If you have just updated a gem version and are now getting an error that Bundler cannot find compatible versions for it then first try running 'bundle update <gemname>'."
            puts "For example if you have just changed the version of origen_core run 'bundle update origen_core'."
            exit 1
          end
        end
      else
        Bundler.setup
      end
    end
    require 'bundler/setup'
    require 'origen'
  else
    $LOAD_PATH.unshift "#{File.expand_path(File.dirname(__FILE__))}/../lib"
    require 'origen'
  end

########################################################################################################################
########################################################################################################################
## We are running outside of an app and no-special global Origen tool setup is present
########################################################################################################################
########################################################################################################################
else
  $LOAD_PATH.unshift "#{File.expand_path(File.dirname(__FILE__))}/../lib"
  require 'origen'
end

########################################################################################################################
########################################################################################################################

begin
  # Now that the runtime Origen version is loaded, we need to re-load the site config.
  # This is because the version of the site_config that was originally loaded above has instantiated
  # a site_config object, whereas earlier versions of Origen (which could now be loaded), instantiated
  # a simple hash instead.
  # Reloading now will ensure consistency between the site config object and the version of
  # Origen that is now live.
  Origen.instance_variable_set(:@site_config, nil)
  load 'origen/site_config.rb'
  require 'colored'
  # Emit all broadcast messages before executing all commands
  if Origen.site_config.broadcast_info
    puts
    Array(Origen.site_config.broadcast_info).each { |line| puts line }
    puts
  end
  if Origen.site_config.broadcast_warning
    puts
    Array(Origen.site_config.broadcast_warning).each { |line| puts line.yellow }
    puts
  end
  if Origen.site_config.broadcast_danger
    puts
    Array(Origen.site_config.broadcast_danger).each { |line| puts line.red }
    puts
  end
  if Origen.site_config.broadcast_success
    puts
    Array(Origen.site_config.broadcast_success).each { |line| puts line.green }
    puts
  end

  # If this script has been invoked from within an Origen application then open
  # up all commands, if not then only allow the command to create a new Origen
  # application.
  if origen_root && boot_app
    puts warnings if warnings && Origen.version >= '0.40.0'
    require 'origen/commands'
  else
    require 'origen/commands_global'
  end
rescue Exception => e
  # A formatted stack dump will not be printed if the application ends via 'exit 0' or 'exit 1'. In that
  # case the application code is responsible for printing a helpful error message.
  # This will intercept all other exits, e.g. via 'fail "Something has done wrong"', and split the stack
  # dump to separate all in-application references from Origen core/plugin references.
  if e.is_a?(SystemExit)
    exit e.status
  else
    puts
    if Origen.app_loaded?
      puts 'COMPLETE CALL STACK'
      puts '-------------------'
      puts e.message unless e.is_a?(SystemExit)
      puts e.backtrace

      puts
      puts 'APPLICATION CALL STACK'
      puts '----------------------'
      puts e.message unless e.is_a?(SystemExit)
      # Only print out the application stack trace by default, if verbose logging is
      # enabled then output the full thing
      e.backtrace.each do |line|
        path = Pathname.new(line)
        if path.absolute?
          if line =~ /^#{Origen.root}/ && line !~ /^#{Origen.root}\/lbin/
            puts line
          end
        else
          puts line unless line =~ /^.\/lbin/
        end
      end
    else
      puts 'COMPLETE CALL STACK'
      puts '-------------------'
      puts e.message unless e.is_a?(SystemExit)
      puts e.backtrace
    end
    exit 1
  end
ensure
  if Origen.app_loaded?
    Origen.app.listeners_for(:on_origen_shutdown).each(&:on_origen_shutdown)
    Origen.app.runner.shutdown
  end
end
