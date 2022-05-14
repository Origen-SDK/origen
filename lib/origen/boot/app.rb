require 'fileutils'
module Origen
  # Provides methods for setting up, booting and
  # archiving an Origen application
  module Boot
    # Gem executables that Origen depends on [bin name, gem name]
    BIN_DEPS = [%w(rspec rspec-core), %w(nanoc nanoc), %w(yard yard),
                %w(rubocop rubocop), %w(rake rake)]

    BUNDLER_WARNING = '
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

    BUNDLER_SETUP = %q(
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

    UPDATER_WARNING = '
The bin/fix_my_workspace script is not compatible with the new way that Origen is
launched and you should remove it from your application.

Do this by deleting bin/fix_my_workspace and also remove the origen_updater gem from
your application.

The command `origen setup` can be used in place of fix_my_workspace under the
new system, however the new system should be more robust and such workspace repairs
should no longer be required.

______________________________________________________________________________________

'

    BINSTUB =
"#!/usr/bin/env ruby
#
# This file was generated by Origen.
#

require 'rubygems'

origen_lib = File.expand_path('../../lib/origen', Gem.bin_path('origen', 'origen'))
boot = File.join(origen_lib, 'boot.rb')
ORIGEN_ROOT = File.expand_path('..', __dir__)
origen_root = ORIGEN_ROOT

# If the Origen version supports the new boot system then use it
if File.exist?(boot)
  load boot

# Otherwise fall back to an (improved) old-style invocation via Bundler
else
  require 'pathname'
  require 'fileutils'
  $_origen_invocation_pwd = Pathname.pwd
  require File.join(origen_lib, 'site_config')
" + BUNDLER_SETUP + %q(
  bundle_binstub = File.expand_path('../bundle', __FILE__)

  if File.file?(bundle_binstub)
    if File.read(bundle_binstub, 300) =~ /This file was generated by Bundler/
      load(bundle_binstub)
    else
      abort("Your `bin/bundle` was not generated by Bundler, so this binstub cannot run.
  Replace `bin/bundle` by running `bundle binstubs bundler --force`, then run this command again.")
    end
  end
  require 'bundler/setup'

  load Gem.bin_path('origen', 'origen')
end
)
    class << self
      # Boot the application at the given root
      def app!(origen_root)
        # This will be used to collect warnings about the user's application environment, however showing them
        # will be deferred until it has been determined that the application is using Origen >= 0.40.0 - i.e. we
        # don't want to start complaining to the user about existing apps until they have intentionally upgraded
        # their Origen version.
        warnings = []

        exec_remote = ARGV.include?('--exec_remote') ? true : false
        lbin_dir = File.join(origen_root, 'lbin')
        origen_binstub = File.join(lbin_dir, 'origen')

        unless exec_remote
          if !File.exist?(origen_binstub) ||
             (File.exist?(origen_binstub) && File.read(origen_binstub) !~ /This file was generated by Origen/)
            warnings << BUNDLER_WARNING
          elsif File.exist?(File.join(origen_root, 'bin', 'fix_my_workspace'))
            warnings << UPDATER_WARNING
          end

          setup_bundler(origen_root)
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
            puts
            if exec_remote
              puts 'App failed to boot, run it locally so that this can be resolved before re-submitting to the LSF'
              exit 1
            end
            puts 'Attempting to resolve this...'
            puts

            passed = false

            Bundler.with_clean_env do
              cmd = 'bundle install'
              cmd += ' --local' if File.exist?('.origen_archive')
              passed = system(cmd)
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
        unless exec_remote
          # The application's bundle is safely loaded, do a final check to make sure that Origen's
          # required bin dependencies have binstubs
          if BIN_DEPS.any? { |bin, gem| !File.exist?(File.join(lbin_dir, bin)) }
            system "bundle binstubs #{BIN_DEPS.map { |bin, gem| gem }.join(' ')} --path #{lbin_dir} --force"
          end
        end
        require 'origen'
        warnings
      end

      def setup(origen_root)
        create_origen_binstub(origen_root)
        bundle_path = setup_bundler(origen_root)
        unless File.exist?(File.join(origen_root, '.origen_archive'))
          copy_system_gems(origen_root, bundle_path)
        end
      end

      def create_origen_binstub(origen_root)
        lbin_dir = File.join(origen_root, 'lbin')

        FileUtils.mkdir_p(lbin_dir)
        File.open(File.join(lbin_dir, 'origen'), 'w') do |f|
          f.puts BINSTUB
        end
        FileUtils.chmod('+x', File.join(lbin_dir, 'origen'))

        if Origen.os.windows?
          Dir.glob("#{origen_root}/lbin/*").each do |bin|
            unless bin =~ /.bat$/
              bat = "#{bin}.bat"
              unless File.exist?(bat)
                File.open(bat, 'w') { |f| f.write('@"ruby.exe" "%~dpn0" %*') }
              end
            end
          end
        end
      end

      def setup_bundler(origen_root)
        bundle_path = nil
        eval BUNDLER_SETUP # Will update bundle_path
        bundle_path
      end

      def copy_system_gems(origen_root, bundle_path)
        if Origen.site_config.gem_use_from_system
          local_gem_dir = "#{bundle_path}/ruby/#{Pathname.new(Gem.dir).basename}"
          gem_dir = Pathname.new(Gem.dir)

          Origen.site_config.gem_use_from_system.each do |gem, version|
            
              # This will raise an error if the system doesn't have this gem installed, that
              # will be rescued below
              spec = Gem::Specification.find_by_name(gem, version)

              # If the spec has returned a handle to a system installed gem. If this script has been invoked through
              # Bundler then it could point to some other gem dir. The only time this should occur is when switching
              # from the old system to the new system, but can't work out how to fix it so just disabling in that case.
              if spec.gem_dir =~ /#{gem_dir}/

                local_dir = File.join(local_gem_dir, Pathname.new(spec.gem_dir).relative_path_from(gem_dir))
                FileUtils.mkdir_p local_dir
                FileUtils.cp_r("#{spec.gem_dir}/.", local_dir)

                local_file = Pathname.new(File.join(local_gem_dir, Pathname.new(spec.cache_file).relative_path_from(gem_dir)))
                FileUtils.mkdir_p local_file.dirname
                FileUtils.cp(spec.cache_file, local_file)

                if spec.extension_dir && File.exist?(spec.extension_dir)
                  local_dir = File.join(local_gem_dir, Pathname.new(spec.extension_dir).relative_path_from(gem_dir))
                  FileUtils.mkdir_p local_dir
                  FileUtils.cp_r("#{spec.extension_dir}/.", local_dir)
                end

                local_file = Pathname.new(File.join(local_gem_dir, Pathname.new(spec.spec_file).relative_path_from(gem_dir)))
                FileUtils.mkdir_p local_file.dirname
                FileUtils.cp(spec.spec_file, local_file)

                puts "Copied #{gem} #{version} from the system into #{bundle_path}"

              end

            rescue Exception # Gem::LoadError  # Rescue everything here, this is a try-our-best operation, better to
              # continue and try and install the gem if this fails rather than crash
              # This just means that one of the gems that should be copied from the system
              # was not actually installed in the system, so nothing we can do about that here
            
          end
        end
      end
    end
  end
end
