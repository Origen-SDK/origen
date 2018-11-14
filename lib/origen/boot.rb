$VERBOSE = nil  # Don't care about world writable dir warnings and the like

require 'pathname'
require 'fileutils'

# Gem executables that Origen depends on [bin name, gem name]
ORIGEN_BIN_DEPS = [%w(rspec rspec-core), %w(nanoc nanoc), %w(yard yard),
                   %w(rubocop rubocop), %w(rake rake)]

ORIGEN_BUNDLER_WARNING = '
From Origen 0.40.0 onwards, a new way of launching Origen is supported and
you are seeing this message because your application is still setup to run
the old way.

The main difference is that Origen is now launched via an Origen-owned binstub
(./lbin/origen) rather than a Bundler-owned binstub. This means that Origen can
no longer be prevented from running due to a Bundler configuration issue within
your workspace and it should mean that Origen invocation becomes more reliable.

It is recommended that you follow these instructions to upgrade your application
to the new system.

If have already done this and you are seeing this message again, then Bundler has
overwritten the binstub at ./lbin/origen and you should perform the upgrade again.

To upgrade, run the following command:

 origen setup

If you ever run the `bundle` or `bundle install` commands manually, never use
the --binstubs option or it will roll you back to the old system.

Under the new system, you should check the `./lbin` directory into your source
control system, so remove it from your `.gitignore` (or equivalent) and check
it in.

When you install a new gem whose executable you want to use in your app,
generate a binstub for it via the following command:

  origen new binstub some-gem-name

______________________________________________________________________________________

'

ORIGEN_BUNDLER_SETUP = %q(
  if Origen.site_config.gem_manage_bundler
    FileUtils.mkdir_p(File.join(origen_root, '.bundle'))
    File.open(File.join(origen_root, '.bundle', 'config'), 'w') do |f|
      f.puts '# Origen is managing this file, any local edits will be overwritten'
      f.puts '# IT SHOULD NOT BE CHECKED INTO REVISION CONTROL!'
      f.puts '---'
      f.puts 'BUNDLE_BIN: false'
      # If gems have been installed to the app, always use them
      bundle_path = File.join(origen_root, 'vendor', 'gems')
      if File.exist?(bundle_path)
        # Only keep the gems we actually need when installing to the application, but
        # don't do this when installing outside since other apps might use them
        f.puts 'BUNDLE_CLEAN: true'
      else
        bundle_path = File.expand_path(Origen.site_config.gem_install_dir)
      end
      f.puts "BUNDLE_PATH: \"#{bundle_path}\""
      Array(Origen.site_config.gem_build_switches).each do |build_switches|
        switches = build_switches.strip.split(' ')
        gem = switches.shift
        f.puts "BUNDLE_BUILD__#{gem.upcase}: \"#{switches.join(' ')}\""
      end
    end
  end
)

ORIGEN_UPDATER_WARNING = '
The bin/fix_my_workspace script is not compatible with the new way that Origen is
launched and you should remove it from your application.

Do this by deleting bin/fix_my_workspace and also remove the origen_updater gem from
your application.

The command `origen setup` can be used in place of fix_my_workspace under the
new system, however the new system should be more robust and such workspace repairs
should no longer be required.

______________________________________________________________________________________

'

ORIGEN_PATH_WARNING = %q(
Warning, your PATH does not contain ./lbin which is expected by Origen
You can correct this by adding one of the following lines to the end of your
environment setup file:

  In ~/.bashrc or ~/.bashrc.user:  export PATH="./lbin:$PATH"'
  In ~/.tcshrc or ~/.tcshrc.user:  setenv PATH "./lbin:$PATH"'

______________________________________________________________________________________

)

class OrigenBootError < StandardError
end

# Keep a note of the pwd at the time when Origen was first loaded, this is initially used
# by the site_config lookup.
$_origen_invocation_pwd ||= Pathname.pwd

require_relative 'operating_systems'
require_relative 'site_config'

# This will be referenced later in ruby_version_check, the origen used to launch
# the process is different than the one that actually runs under bundler
$origen_launch_root = Pathname.new(File.dirname(__FILE__)).parent

# Override any influence from $LANG in the users environment
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
ENV['LC_ALL'] = nil
ENV['LANG'] = nil
ENV['LANG'] = 'en_US.UTF-8'

# Are we inside an Origen application workspace?
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
end

########################################################################################################################
########################################################################################################################
## If running inside an application workspace
########################################################################################################################
########################################################################################################################
if origen_root
  if ARGV.first == 'setup'
    ORIGEN_ROOT = origen_root
    require_relative 'boot/setup'
    exit 0
  end

  _exec_remote = ARGV.include?('--exec_remote') ? true : false
  lbin_dir = File.join(origen_root, 'lbin')
  origen_binstub = File.join(lbin_dir, 'origen')

  unless _exec_remote
    puts ORIGEN_PATH_WARNING unless ENV['PATH'] =~ /(^|:)\.\/lbin(:|$)/

    if !File.exist?(origen_binstub) ||
       (File.exist?(origen_binstub) && File.read(origen_binstub) !~ /This file was generated by Origen/)
      puts ORIGEN_BUNDLER_WARNING
    elsif File.exist?(File.join(origen_root, 'bin', 'fix_my_workspace'))
      puts ORIGEN_UPDATER_WARNING
    end

    eval ORIGEN_BUNDLER_SETUP
  end

  boot_app = true

  Dir.chdir origen_root do
    # Overriding bundler here so that bundle install can be automated as required, otherwise if just call
    # require 'bundler/setup' then it will exit in the event of errors
    require 'bundler'
    begin
      Bundler.setup
    rescue Gem::LoadError, Bundler::BundlerError => e
      puts e
      if _exec_remote
        puts 'App failed to boot, run it locally so that this can be resolved before re-submitting to the LSF'
        exit 1
      end
      puts 'Attempting to resolve this...'
      puts

      passed = false

      Bundler.with_clean_env do
        passed = system('bundle install')
      end

      if passed
        Bundler.with_clean_env do
          exec "origen #{ARGV.join(' ')}"
        end
        exit 0
      else
        puts
        puts "If you have just updated a gem version and are now getting an error that Bundler cannot find compatible versions for it then first try running 'bundle update <gemname>'."
        puts "For example if you have just changed the version of origen run 'bundle update origen'."
        exit 1
      end
    end
  end
  unless _exec_remote
    # The application's bundle is safely loaded, do a final check to make sure that Origen's
    # required bin dependencies have binstubs
    if ORIGEN_BIN_DEPS.any? { |bin, gem| !File.exist?(File.join(lbin_dir, bin)) }
      system "bundle binstubs #{ORIGEN_BIN_DEPS.map { |bin, gem| gem }.join(' ')} --path #{lbin_dir} --force"
    end
    if Origen.site_config.use_bootsnap && !Origen.os.windows?
      ENV['BOOTSNAP_CACHE_DIR'] ||= "#{origen_root}/tmp/cache"
      require 'bootsnap/setup'
    end
  end
  require 'origen'

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
  # If this script has been invoked from within an Origen application then open
  # up all commands, if not then only allow the command to create a new Origen
  # application.
  if origen_root && boot_app
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
