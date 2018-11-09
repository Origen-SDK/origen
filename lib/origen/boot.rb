$VERBOSE = nil  # Don't care about world writable dir warnings and the like

require 'pathname'
require 'fileutils'
#require 'byebug' # Un-comment to debug this file

BUNDLER_WARNING = %q(
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
overwritten the binstub at ./lbin/origen was created by Origen then you should
run it again.

To upgrade, run the following command:

 origen boot:setup

If you ever run the `bundle` or `bundle install` commands manually, never use
the --binstubs option or it will roll you back to the old system.

Under the new system, you should check the `./lbin` directory into your source
control system, so remove it from your `.gitinore` and/or add and check it in.

When you install a new gem whose executable you want to use in your app,
generate a binstub for it via the following command:

  origen new binstub some-gem-name
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
if defined?(ORIGEN_APP_ROOT)
  origen_root = ORIGEN_APP_ROOT
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
  if ARGV.first == 'boot:setup'
    ORIGEN_APP_ROOT = origen_root
    require_relative 'boot/setup'
    exit 0
  end

  # Here we need to support two systems:
  #   1. The original method of booting Origen through a Bundler-generated binstub (./lbin/origen)
  #   2. The new method where Origen has been invoked from the system Ruby or through a thin Origen-generated binstub
  # 
  # The new method is preferred since it means that an application workspace cannot be prevented from invoking Origen
  # because of a Bundler configuration issue with the workspace. Under the new system, Origen can take more control over
  # the Bundler configuration to prevent such things happening in the first place, and then even if they do we can now
  # help to fix it rather than being prevented from executing entirely.

  # If the system Ruby has been updated to a version that supports the new system, then we will prompt the user on how
  # to update their application, otherwise we will continue largely as before.

  # Get a path to where this file would live in the system Ruby if it is present. Note that the fact that we are
  # executing here does not necessarily mean it is present, we could be running from within an application gem bundle
  # while the external system Ruby still has an old Origen.
  require 'rubygems'
  origen_boot = File.expand_path('../../lib/origen/boot.rb', Gem.bin_path("origen", "origen"))
  origen_binstub = File.join(origen_root, 'lbin', 'origen')

  if File.exist?(origen_boot)
    # Proceed with the environment setup checks...
    unless ENV["PATH"] =~ /(^|:)\.\/lbin2(:|$)/
      puts 'Warning, your PATH does not contain ./lbin which is expected by Origen'
      puts 'You can correct this by adding one of the following lines to the end of your environment setup file:'
      puts
      puts '  In ~/.bashrc or ~/.bashrc.user:  export PATH="./lbin:$PATH"'
      puts '  In ~/.tcshrc or ~/.tcshrc.user:  setenv PATH "./lbin:$PATH"'
      puts
    end

    if !File.exist?(origen_binstub) ||
      (File.exist?(origen_binstub) && File.read(origen_binstub) !~ /This file was generated by Origen/)
      puts BUNDLER_WARNING
    end
  end


  exit 0



  # To (try) and make the logic in this file easier to follow, let's define a few variables up
  # front to identify the various boot conditions we could be in.
  #
  # We can already tell whether we are inside an Origen application or not by whether origen_root
  # has been set or not.
  #
  # When inside an app, the following invocation scenarios can exist:
  #   1. Origen has been invoked via an Origen binstub (new system)
  new_setup = defined?(ORIGEN_APP_ROOT)
  #   2. Origen has been invoked via a Bundler binstub (old system)
  old_setup = !binstub_origen &&  ENV['BUNDLE_BIN_PATH']# && File.exist?(
  #   3. The system Origen has been invoked inside of an application workspace (app not setup yet)
  no_setup = !new_setup && !old_setup

  new_boot_system = defined?(ORIGEN_APP_ROOT)
  new_boot_system = false

  # Force everyone to have a consistent way of installing gems with bundler
  ENV['BUNDLE_GEMFILE'] = File.join(origen_root, 'Gemfile')
  # If gems have been installed to the app, always use them
  vendor_gems = File.join(Dir.pwd, 'vendor', 'gems')
#  if File.exist?(vendor_gems)
#    ENV['BUNDLE_PATH'] = vendor_gems
#  else
    ENV['BUNDLE_PATH'] = File.expand_path(Origen.site_config.gem_install_dir)
#  end

  # Don't do this any more. The benefit of doing this is that it means that if the app bundles a new version of
  # Origen, then the latest and greatest origen executable will be used from here on in.
  # However, a big downside is that it means that Bundler gets invoked before Origen, and so we loose the ability
  # to fully manage Bundler.
  unless new_boot_system
    # If it looks like a bundled binstub of origen exists, and we have not been invoked through that,
    # then run that instead.
    if Origen.site_config.gem_manage_bundler && File.exist?("#{origen_root}/lbin/origen") && !ENV['BUNDLE_BIN_PATH'] &&
       File.exist?(File.expand_path(Origen.site_config.gem_install_dir))
      exec Gem.ruby, "#{origen_root}/lbin/origen", *ARGV
      exit 0
    end
  end
  
  boot_app = true

#if origen_root && File.exist?(ENV['BUNDLE_GEMFILE']) && Origen.site_config.gem_manage_bundler && (boot_app || Origen.site_config.user_install_enable || Origen.site_config.tool_repo_install_dir)
#  # Overriding bundler here so that bundle install can be automated as required
#  require 'bundler/shared_helpers'
#  if Bundler::SharedHelpers.in_bundle?
#    require 'bundler'
#    if STDOUT.tty?
#      begin
#        fail OrigenBootError unless File.exist?(ENV['BUNDLE_BIN'])
#        Bundler.setup
#        fail OrigenBootError unless File.exist?(ENV['BUNDLE_BIN'])
#      rescue Gem::LoadError, Bundler::BundlerError, OrigenBootError => e
#        cmd = "bundle install --gemfile #{ENV['BUNDLE_GEMFILE']} --binstubs #{ENV['BUNDLE_BIN']} --path #{ENV['BUNDLE_PATH']}"
#        # puts cmd
#        puts 'Installing required gems...'
#        puts
#        `chmod o-w #{origen_root}` # Stops some annoying world writable warnings during install
#        `chmod o-w #{origen_root}/bin` if File.exist?("#{origen_root}/bin")
#        `chmod o-w #{origen_root}/.bin` if File.exist?("#{origen_root}/.bin")
#        result = false
#
#        Bundler.with_clean_env do
#          if Origen.os.unix?
#            if Origen.site_config.gem_build_switches
#              Origen.site_config.gem_build_switches.each do |switches|
#                `bundle config build.#{switches}`
#              end
#            end
#          end
#          result = system(cmd)
#        end
#        `chmod o-w #{ENV['BUNDLE_BIN']}`
#        # Make .bat versions of all executables, Bundler should really be doing this when running
#        # on windows
#        if Origen.os.windows?
#          bat_present = File.exist? "#{origen_root}/lbin/origen.bat"
#          Dir.glob("#{origen_root}/lbin/*").each do |bin|
#            unless bin =~ /.bat$/
#              bat = "#{bin}.bat"
#              unless File.exist?(bat)
#                File.open(bat, 'w') { |f| f.write('@"ruby.exe" "%~dpn0" %*') }
#              end
#            end
#          end
#          if !bat_present && !result
#            puts 'Some Windows specific updates to your workspace were required, please re-run the last command'
#            exit 0
#          end
#        end
#        if result
#          exec "origen #{ARGV.join(' ')}"
#          exit 0
#        else
#          puts
#          puts "If you have just updated a gem version and are now getting an error that Bundler cannot find compatible versions for it then first try running 'bundle update <gemname>'."
#          puts "For example if you have just changed the version of origen_core run 'bundle update origen_core'."
#          exit 1
#        end
#      end
#    else
#      Bundler.setup
#    end
#  end
#  require 'bundler/setup'
#  _exec_remote = ARGV.include?('--exec_remote') ? true : false  
#  if Origen.site_config.use_bootsnap && !Origen.os.windows? && !_exec_remote
#    ENV["BOOTSNAP_CACHE_DIR"] ||= "#{origen_root}/tmp/cache"
#    require 'bootsnap/setup'
#  end
#  require 'origen'



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
  unless Dir.exists?(install_dir)
    load File.expand_path('../../lib/origen/utility/input_capture.rb', __FILE__)
    include Origen::Utility::InputCapture
    
    puts "Root directory '#{install_dir}' does not exist. Would you like to create it?"
    if get_text(confirm: :return_boolean)
      FileUtils.mkdir(install_dir)
    else
      puts "Exiting with creating Origen install"
      exit!
    end
  end
  
  gemfile = File.join(install_dir, 'Gemfile')
  unless File.exists?(gemfile)
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
