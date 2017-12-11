# This guard is temporary to help Freescale transition to Origen from
# our original internal version (RGen)
unless defined? RGen::ORIGENTRANSITION
  require 'English'
  require 'pathname'
  require 'pry'
  # require these here to make required files consistent between global commands invoke globally and global commands
  # invoked from an application workspace
  require 'colored'
  require 'fileutils'
  # Keep a note of the pwd at the time when Origen was first loaded, this is initially used
  # by the site_config lookup.
  $_origen_invocation_pwd ||= Pathname.pwd
  require 'fileutils'
  require 'origen/site_config'
  require 'origen/operating_systems'
  require 'origen/core_ext'
  require 'origen/acronyms'
  require 'origen/callbacks'
  require 'origen/top_level'
  require 'origen/model'
  require 'origen/ruby_version_check'
  require 'origen/application'
  require 'origen/remote_manager'
  require 'origen/utility'
  require 'origen/logger_methods'
  require 'option_parser/optparse'
  require 'bundler'
  require 'origen/undefined'

  module Origen
    autoload :Features,          'origen/features'
    autoload :Bugs,              'origen/bugs'
    autoload :Generator,         'origen/generator'
    autoload :Pins,              'origen/pins'
    autoload :Registers,         'origen/registers'
    autoload :Ports,             'origen/ports'
    autoload :Users,             'origen/users'
    autoload :FileHandler,       'origen/file_handler'
    autoload :RegressionManager, 'origen/regression_manager'
    autoload :Location,          'origen/location'
    autoload :VersionString,     'origen/version_string'
    autoload :Mode,              'origen/mode'
    autoload :ChipMode,          'origen/chip_mode'
    autoload :ChipPackage,       'origen/chip_package'
    autoload :Client,            'origen/client'
    autoload :SubBlocks,         'origen/sub_blocks'
    autoload :SubBlock,          'origen/sub_blocks'
    autoload :ModelInitializer,  'origen/model_initializer'
    autoload :Controller,        'origen/controller'
    autoload :Database,          'origen/database'
    autoload :Parameters,        'origen/parameters'
    autoload :RevisionControl,   'origen/revision_control'
    autoload :Specs,             'origen/specs'
    autoload :CodeGenerators,    'origen/code_generators'
    autoload :Encodings,         'origen/encodings'
    autoload :Log,               'origen/log'
    autoload :Chips,             'origen/chips'
    autoload :Netlist,           'origen/netlist'
    autoload :Models,            'origen/models'
    autoload :Errata,            'origen/errata'
    autoload :LSF,               'origen/application/lsf'
    autoload :LSFManager,        'origen/application/lsf_manager'
    autoload :Fuses,             'origen/fuses'
    autoload :Tests,             'origen/tests'
    autoload :PowerDomains,      'origen/power_domains'
    autoload :Clocks,            'origen/clocks'

    attr_reader :switch_user

    APP_CONFIG = File.join('config', 'application.rb')

    class OrigenError < StandardError
      def self.status_code(code)
        define_method(:status_code) { code }
      end
    end

    class GitError < OrigenError; status_code(11); end
    class DesignSyncError < OrigenError; status_code(12); end
    class RevisionControlUninitializedError < OrigenError; status_code(13); end

    class << self
      include Origen::Utility::TimeAndDate

      def enable_profiling
        @profiling = true
      end

      def disable_profiling
        @profiling = false
      end

      def profile(message)
        if @profiling
          caller[0] =~ /.*\/(\w+\.rb):(\d+).*/
          if block_given?
            start = Time.now
            yield
            duration_in_ms = ((Time.now - start) * 1000).round
            puts "#{duration_in_ms}ms".ljust(10) + "#{Regexp.last_match[1]}:#{Regexp.last_match[2]} '#{message}'"
          else
            puts "#{Time.now} - #{Regexp.last_match[1]}:#{Regexp.last_match[2]} #{message}"
          end
        else
          yield if block_given?
        end
      end

      def register_application(app)
        _applications_lookup[:name][app.name] = app
        _applications_lookup[:root][app.root.to_s] = app
        @plugins = nil
      end

      def plugins
        Origen.deprecate 'Origen.plugins is deprecated, use Origen.app.plugins instead'
        Origen.app.plugins
      end

      def application_loaded?
        @application_loaded
      end
      alias_method :app_loaded?, :application_loaded?

      def plugins_loaded?
        @plugins_loaded
      end

      # Returns the current (top-level) application instance
      def app(plugin = nil, _options = {})
        plugin, options = nil, plugin if plugin.is_a?(Hash)
        if plugin
          load_application
          app = _applications_lookup[:name][plugin.to_sym]
          if app
            app
          else
            puts "Couldn't find application instance called #{plugin}, known names are:"
            puts "  #{_applications_lookup[:name].keys.join(', ')}"
            puts
            fail 'Origen.root lookup error!'
          end
        else
          load_application
        end
      end
      alias_method :application, :app

      # Equivalent to application except that if called from code in a plugin this
      # will return that plugin's application instance
      def app!
        file = caller[0]
        path = @current_source_dir || Pathname.new(file).dirname
        until File.exist?(File.join(path, APP_CONFIG)) || path.root?
          path = path.parent
        end
        if path.root?
          fail "Something went wrong resoving Origen.app! from: #{caller[0]}"
        end
        find_app_by_root(path)
      end
      alias_method :application!, :app!

      def has_plugin?(plugin)
        _applications_lookup[:name][plugin.to_sym].nil? ? false : true
      end

      # @api private
      def with_source_file(file)
        @current_source_dir = Pathname.new(file).dirname
        yield
        @current_source_dir = nil
      end

      # Validates that when the current app is OrigenCore then the
      # origen executable is coming from the same workspace
      #
      # @api private
      def validate_origen_dev_configuration!
        if Origen.app.name == :origen_core
          if Origen.root != Origen.top
            puts 'It looks like you are trying to develop Origen core, but you are running an Origen'
            puts 'executable from another workspace!'
            if Origen.running_on_windows?
              puts 'To resolve this error you must add the following directory to your Windows PATH:'
              puts "  #{Origen.root}\\bin"
            else
              puts 'To resolve this error run:'
              puts "  cd #{Origen.root}"
              puts '  source source_setup'
            end
            exit 1
          end
        end
      end

      # @api private
      def _applications_lookup
        @_applications_lookup ||= { name: {}, root: {} }
      end

      # Returns an instance of Origen::Users::LDAP which provides
      # methods to query and authorize users against a company's LDAP-based employee directory
      def ldap
        @ldap ||= Origen::Users::LDAP.new
      end

      # Return the application instance from the given path
      # to an Origen application workspace, i.e. Origen.app conventionally
      # returns the current application instance, this method returns the
      # same thing that would be returned from the given remote workspace.
      #
      # @api private
      def find_app_by_root(path_to_origen_root, options = {})
        app = _applications_lookup[:root][Pathname.new(path_to_origen_root).realpath.to_s]
        if !app || options[:reload]
          # If the application is already defined then un-define it, this is to allow it to
          # be reloaded.
          # This option feels like it doesn't belong here, but is part of the legacy import
          # require system. When that has been removed in future so can this reload system, under
          # bundler app versions will be resolved before loading them so there will be no need
          # for this
          if app
            begin
              Object.send(:remove_const, app.class.to_s)
            rescue
              # Nothing to do here
            end
          end
          require File.join(path_to_origen_root, APP_CONFIG)
          app = _applications_lookup[:root][Pathname.new(path_to_origen_root).realpath.to_s]
        end
        return app if app
        puts "Couldn't find application instance with root #{path_to_origen_root}, known roots are:"
        _applications_lookup[:root].keys.each do |key|
          puts "  #{key}"
        end
        puts
        fail 'Application lookup error!'
      end
      alias_method :application_instance, :find_app_by_root
      alias_method :app_instance, :find_app_by_root

      def command_dispatcher
        @command_dispatcher ||= Application::CommandDispatcher.new
      end

      def configuration
        app.config
      end
      alias_method :config, :configuration

      def mailer
        application.mailer
      end

      def target
        application.target
      end

      def load_target(t = nil, options = {})
        t, options = nil, t if t.is_a?(Hash)
        target.temporary = t if t
        application.load_target!(options)
        application.runner.prepare_and_validate_workspace
      end

      def environment
        application.environment
      end

      # Returns true if Origen is running in an application workspace
      def in_app_workspace?
        @in_app_workspace ||= begin
          path = Pathname.new(Dir.pwd)
          until path.root? || File.exist?(File.join(path, APP_CONFIG))
            path = path.parent
          end
          !path.root?
        end
      end

      # Shortcut method to find if Origen was invoked from within an application or from
      # the global Origen install. This is just the opposite of in_app_workspace?
      def running_globally?
        @running_globally ||= !in_app_workspace?
      end
      alias_method :invoked_globally?, :running_globally?

      def root(plugin = nil)
        if plugin
          app(plugin).root
        else
          if @root_fudge_active
            app.root
          else
            @root ||= begin
              path = Pathname.new(Dir.pwd)
              until path.root? || File.exist?(File.join(path, APP_CONFIG))
                path = path.parent
              end
              if path.root?
                @running_globally = true
                path = Pathname.new($_origen_invocation_pwd || Dir.pwd)
              else
                @in_app_workspace = true
              end
              path
            end
          end
        end
      end
      alias_method :app_root, :root

      # Like Origen.root but this will return the plugin root if called by plugin code
      def root!
        file = caller[0]
        path = Pathname.new(file).dirname
        until path.root? || File.exist?(File.join(path, APP_CONFIG))
          path = path.parent
        end
        if path.root?
          fail "Something went wrong resolving Origen.root! from: #{caller[0]}"
        end
        path.realpath
      end

      # Ugly hack to force Origen.root references to the plugin's top-level when loading
      # the environment.rb of the plugin
      #
      # References to Origen.root in a plugin environment.rb is deprecated and this will be
      # removed in future once all plugins load through bundler
      #
      # @api private
      def with_origen_root(path)
        orig = app.root
        @root_fudge_active = true
        app.root = Pathname.new(path)
        yield
        app.root = orig
        @root_fudge_active = false
      end

      # This is similar to the command line of 'sudo <user_name>'.  The main
      # use case is when someone is running with a Service Account and needs
      # to change to an actually user instead of the service account
      def with_user(user_obj, &block)
        @switch_user = user_obj
        block.call
        @switch_user = nil
      end

      # Turns off bundler and all plugins if the app is loaded within this block
      # @api private
      def with_boot_environment
        @with_boot_environment = true
        yield
        @with_boot_environment = false
      end

      # This is the application-facing API for implementing custom callbacks,
      # the top-level application, all plugin application instances, and any
      # application objects that include the Origen::Callbacks module will be
      # returned
      #
      # Origen system callbacks should use Origen.app.listeners_for instead, that
      # version will return only the current plugin instance instead of them all
      # (yes we need to make the API more obvious).
      def listeners_for(*args)
        callback = args.shift
        max = args.first.is_a?(Numeric) ? args.shift : nil
        listeners = [Origen.app] + Origen.app.plugins +
                    Origen.app.instantiated_callback_listeners
        listeners = listeners.select { |l| l.respond_to?(callback) }
        if max && listeners.size > max
          fail "You can only define a #{callback} callback #{max > 1 ? (max.to_s + 'times') : 'once'}, however you have declared it #{listeners.size} times for instances of: #{listeners.map(&:class)}"
        end
        listeners
      end

      def generator
        @generator ||= Generator.new
      end

      def client
        @client ||= Client.new
      end

      def tester
        application && application.tester
      end

      def pin_bank
        @pin_bank ||= Pins::PinBank.new
      end

      def file_handler
        @file_handler ||= FileHandler.new
      end

      def regression_manager
        @regression_manager ||= RegressionManager.new
      end

      def import_manager
        Origen.deprecated 'Origen.import_manager is deprecated, use Origen.app.plugins instead'
        app.plugins
      end
      alias_method :imports_manager, :import_manager

      def plugins_manager
        Origen.deprecated 'Origen.plugins_manager and Origen.current_plugin are deprecated, use Origen.app.plugins instead'
        app.plugins
      end
      alias_method :plugin_manager, :plugins_manager
      alias_method :current_plugin, :plugins_manager

      def remote_manager
        @remote_manager ||= RemoteManager.new
      end
      alias_method :remotes_manager, :remote_manager

      def pattern
        generator.pattern
      end

      def flow
        generator.flow
      end

      def resources
        generator.resources
      end

      def time
        @time ||= Origen::Tester::Time.new
      end

      def controllers
        @controllers ||= []
      end

      def version(options = {})
        @version = nil if options[:refresh]
        return @version if @version && !options[:refresh]
        if options[:refresh] || !defined?(Origen::VERSION)
          load File.join(Pathname.new(File.dirname(__FILE__)).parent, 'config', 'version.rb')
        end
        @version = Origen::VersionString.new(Origen::VERSION)
      end

      # Loads the top-level application and all of its plugins, but not the target
      #
      # In most cases this should never need to be called directly and will be called
      # automatically the first time the application is referenced via Origen.app
      def load_application(options = {})
        @application ||= begin
          # If running globally (outside of an app workspace), instantiate a bare bones app to help
          # many of Origen's features that expect an app to be present.
          if running_globally?
            @plugins_loaded = true
            # Now load the app
            @loading_top_level = true
            require 'origen/global_app'
            @application = _applications_lookup[:root][root.to_s]
            @loading_top_level = false
            @application_loaded = true
            @application
          else
            # Make sure the top-level root is always in the load path, it seems that some existing
            # plugins do some strange things to require stuff from the top-level app and rely on this
            path = File.join(root, 'lib')
            $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
            if File.exist?(File.join(root, 'Gemfile')) && !@with_boot_environment
              # Don't understand the rules here, belt and braces approach for now to make
              # sure that all Origen plugins are auto-required (otherwise Origen won't know
              # about them to plug them into the application)
              Bundler.require
              Bundler.require(:development)
              Bundler.require(:runtime)
              Bundler.require(:default)
            end
            @plugins_loaded = true
            # Now load the app
            @loading_top_level = true
            require File.join(root, APP_CONFIG)
            @application = _applications_lookup[:root][root.to_s]
            @loading_top_level = false
            if @with_boot_environment
              @application.plugins.disable_current
            else
              Origen.remote_manager.require!
            end
            boot = File.join(root, 'config', 'boot.rb')
            require boot if File.exist?(boot)
            env = File.join(root, 'config', 'environment.rb')
            require env if File.exist?(env)
            dev = File.join(root, 'config', 'development.rb')
            require dev if File.exist?(dev)
            validate_origen_dev_configuration!
            ([@application] + Origen.app.plugins).each(&:on_loaded)
            @application_loaded = true
            Array(@after_app_loaded_blocks).each { |b| b.call(@application) }
            @application
          end
        end
      end

      # Sometimes it is necessary to refer to the app instance before it is fully loaded, which can lead to runtime
      # errors.
      #
      # Such code can be wrapped in this method to ensure that it will run safely by differing it until the app
      # is fully loaded.
      #
      # If the application is already loaded by the time this is called, then it will execute straight away.
      #
      #   Origen.after_app_loaded do |app|
      #     app.do_something
      #   end
      def after_app_loaded(&block)
        if application_loaded?
          yield app
        else
          @after_app_loaded_blocks ||= []
          @after_app_loaded_blocks << block
        end
      end

      # @api private
      def loading_top_level?
        @loading_top_level
      end

      def launch_time
        @launch_time ||= time_now
      end

      # Returns the full path to the Origen core top-level directory
      def top
        @origen_top ||= Pathname.new(File.dirname(__FILE__)).parent
      end

      # Compile the given file and return the result as a string
      def compile(file, options = {})
        # This has to operate on a new instance so that helper methods can use the inline
        # compiler within an isolated context
        c = Origen::Generator::Compiler.new
        # It needs to be placed on the stack so that the global render method references
        # the correct compiler instance
        $_compiler_stack ||= []
        $_compiler_stack << c
        r = c.compile_inline(file, options)
        $_compiler_stack.pop
        r
      end

      def interfaces
        @interfaces ||= []
      end

      def add_interface(interface_class)
        interfaces << interface_class
      end

      # Resets the tester interface (instantiates a new one). Any supplied options
      # are passed to the interface initialization.
      def reset_interface(options = {})
        # The doc interface should in future be phased out, but for now assume that an explicitly
        # declared interface is for the non-doc case
        if options[:interface] && !Origen.tester.doc?
          @interface = eval(options[:interface]).new(options)
        else
          int = interfaces.find { |i| i.supports?(Origen.tester) }
          if int
            @interface = int.new(options)
          else
            if defined? OrigenTesters::NoInterface
              @interface = OrigenTesters::NoInterface.new
            else
              unless options.delete(:silence_no_interface_error)
                fail "No interface has been defined for tester: #{Origen.tester.class}"
              end
            end
          end
        end
        @interface._load_generator if @interface.respond_to?(:_load_generator)
        if @interface.respond_to?(:at_flow_start)
          @interface.at_flow_start
        else
          @interface.reset_globals if @interface.respond_to?(:reset_globals)
        end
        @interface
      end

      def interface_loaded?
        !!@interface
      end

      # Returns the (application defined) test program interface for the given tester
      # if one has been defined, otherwise returns nil
      def interface(options = {})
        @interface || reset_interface(options)
      end

      # Returns true if an interface is defined for the current tester
      def interface_present?
        !!interface(silence_no_interface_error: true)
      end

      # Use User.current to retrieve the current user, this is an internal API that will
      # be cleaned up (removed) in future
      # @api private
      def current_user(options = {})
        @current_user = nil if options[:refresh]
        if app_loaded? || in_app_workspace?
          return @switch_user unless @switch_user.nil?
          @current_user ||= application.current_user
        else
          @current_user ||= User.new(User.current_user_id)
        end
      end

      def running_on_windows?
        Origen.os.windows?
      end

      def running_on_linux?
        !running_on_windows?
      end

      def running_remotely?
        @running_remotely
      end
      alias_method :running_remotely, :running_remotely?

      def running_locally?
        !running_remotely?
      end

      def running_remotely=(val)
        @running_remotely = val
      end

      # Returns true if Origen is running with the -d or --debug switches enabled
      def debug?
        @debug || false
      end
      alias_method :debugger?, :debug?

      def enable_debugger
        @debug = true
      end

      def debugger_enabled?
        @debug
      end

      def development?
        # This should be integrated with Origen.config.mode in the future
        @development
      end

      def set_development_mode
        @development = true
      end

      # Returns an object tracking the Origen execution mode/configuration, an
      # instance of Origen::Mode
      def mode
        @mode ||= Origen::Mode.new
      end

      def mode=(val)
        mode.set(val)
      end

      # Returns the current top-level (DUT) object if one has been defined (by
      # instantiating an object that includes Origen::TopLevel).
      def top_level
        application.top_level
      end

      def deprecate(*msgs)
        _deprecate(*msgs)
        if Origen.app
          # If an app deprecation return the caller who called the deprecated method
          if caller[0] =~ /#{Origen.root}/
            c = caller[1]
          # If an Origen deprecation then return the first caller from the current app
          else
            c = caller.find { |line| line =~ /#{Origen.root}/ }
          end
        else
          c = caller[1]
        end
        c =~ /(.*):(\d+):.*/
        begin
          _deprecate "Called by #{Regexp.last_match[1]}:#{Regexp.last_match[2]}", options
        rescue
          # For this to fail it means the deprecated method was called by IRB or similar
          # and in that case there is no point advising who called anyway
        end
      end
      alias_method :deprecated, :deprecate

      def log
        @log ||= Log.new
      end

      # Returns the name of the currently executing Origen command (a String),
      # e.g. 'generate', 'program', 'compile', etc.
      def current_command
        @current_command
      end

      # Provides a global Origen session stored at ~/.origen/session (Origen.home)
      def session(reload = false)
        @session = nil if reload
        @session ||= Database::KeyValueStores.new(self, persist: false)
      end

      # Returns the home directory of Origen (i.e., the primary place that Origen operates out of)
      def home
        File.expand_path(Origen.site_config.home_dir)
      end

      def lsf_manager
        @lsf_manager ||= Origen::Application::LSFManager.new
      end

      # Picks between either the global lsf_manager or the application's LSF manager
      def lsf
        if running_globally?
          lsf_manager
        else
          application.lsf_manager
        end
      end

      # Returns the Origen LSF instance, not the lsf_manager. Use Origen.lsf for that
      def lsf!
        @lsf ||= Origen::Application::LSF.new
      end

      # Let's Origen know about any domain specific acronyms used with an application, this will cause
      # them to be translated between underscored and camel-cased versions correctly
      def register_acronym(name)
        require 'active_support/core_ext/string/inflections'
        ActiveSupport::Inflector.inflections(:en) do |inflect|
          inflect.acronym(name)
        end
      end

      private

      def current_command=(val)
        @current_command = val
      end

      def _deprecate(*lines)
        options = lines.last.is_a?(Hash) ? lines.pop : {}
        lines.flatten.each do |line|
          line.split(/\n/).each do |line|
            log.deprecate line
          end
        end
      end
    end
  end

  # This is already required by commands.rb, but also necessary here so
  # that is included whenever rspec (or another 3rd party) loads Origen
  # outside the scope of an Origen command
  require 'origen/global_methods'
  include Origen::GlobalMethods
end
