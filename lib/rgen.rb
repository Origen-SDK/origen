require 'English'
require 'pathname'
require 'fileutils'
require 'rgen/core_ext'
require 'rgen/acronyms'
require 'rgen/callbacks'
require 'rgen/top_level'
require 'rgen/model'
require 'rgen/ruby_version_check'
require 'rgen/application'
require 'rgen/import_manager'
require 'rgen/remote_manager'
require 'rgen/utility'
require 'rgen/version_checker'
require 'rgen/logger_methods'
require 'option_parser/optparse'
require 'bundler'

module RGen
  autoload :Features,  'rgen/features'
  autoload :Bugs,      'rgen/bugs'
  autoload :Generator, 'rgen/generator'
  autoload :Pins,      'rgen/pins'
  autoload :Registers, 'rgen/registers'
  autoload :Tester,    'rgen/tester'
  autoload :Users,     'rgen/users'
  autoload :FileHandler, 'rgen/file_handler'
  autoload :RegressionManager, 'rgen/regression_manager'
  autoload :NVM,       'rgen/nvm'
  autoload :Location,  'rgen/location'
  autoload :PDM,       'rgen/pdm'
  autoload :VersionString, 'rgen/version_string'
  autoload :Mode,      'rgen/mode'
  autoload :ChipMode,   'rgen/chip_mode'
  autoload :ChipPackage,   'rgen/chip_package'
  autoload :Client,    'rgen/client'
  autoload :SubBlocks,  'rgen/sub_blocks'
  autoload :SubBlock,   'rgen/sub_blocks'
  autoload :ModelInitializer,  'rgen/model_initializer'
  autoload :Controller, 'rgen/controller'
  autoload :Database,   'rgen/database'
  autoload :Parameters, 'rgen/parameters'
  autoload :RevisionControl, 'rgen/revision_control'
  autoload :Specs,      'rgen/specs'
  autoload :CodeGenerators, 'rgen/code_generators'
  autoload :Encodings, 'rgen/encodings'
  autoload :Log,       'rgen/log'

  APP_CONFIG = File.join('config', 'application.rb')
  VAULT = 'sync://sync-15088:15088/Projects/common_tester_blocks/rgen'

  class RGenError < StandardError
    def self.status_code(code)
      define_method(:status_code) { code }
    end
  end

  class GitError < RGenError; status_code(11); end
  class DesignSyncError < RGenError; status_code(12); end

  class << self
    include RGen::Utility::TimeAndDate

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

    # Returns an array containing the application instances of all plugins
    def plugins
      @plugins ||= begin
        top = RGen.app
        plugins = []
        RGen._applications_lookup[:name].each do |_name, app|
          plugins << app unless app == top
        end
        plugins
      end
    end

    def app_loaded?
      @application_loaded
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
          fail 'RGen.root lookup error!'
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
        fail "Something went wrong resoving RGen.app! from: #{caller[0]}"
      end
      find_app_by_root(path)
    end
    alias_method :application!, :app!

    # @api private
    def with_source_file(file)
      @current_source_dir = Pathname.new(file).dirname
      yield
      @current_source_dir = nil
    end

    # Validates that when the current app is RGenCore then the
    # rgen executable is coming from the same workspace
    #
    # @api private
    def validate_rgen_dev_configuration!
      if RGen.app.name == :rgen_core
        if RGen.root != RGen.top
          puts 'It looks like you are trying to develop RGen core, but you are running an RGen'
          puts 'executable from another workspace!'
          if RGen.running_on_windows?
            puts 'To resolve this error you must add the following directory to your Windows PATH:'
            puts "  #{RGen.root}\\bin"
          else
            puts 'To resolve this error run:'
            puts "  cd #{RGen.root}"
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

    # Returns an instance of RGen::Users::ApplicationDirectory which provides
    # methods to query and authorize users against the FSL Application Directory
    def fsl
      @fsl ||= RGen::Users::ApplicationDirectory.new
    end

    # Return the application instance from the given path
    # to an RGen application workspace, i.e. RGen.app conventionally
    # returns the current application instance, this method returns the
    # same thing that would be returned from the given remote workspace.
    #
    # @api private
    def find_app_by_root(path_to_rgen_root, options = {})
      app = _applications_lookup[:root][Pathname.new(path_to_rgen_root).realpath.to_s]
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
        require File.join(path_to_rgen_root, APP_CONFIG)
        app = _applications_lookup[:root][Pathname.new(path_to_rgen_root).realpath.to_s]
      end
      return app if app
      puts "Couldn't find application instance with root #{path_to_rgen_root}, known roots are:"
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

    def load_target(t, options = {})
      target.temporary = t
      application.load_target!(options)
      application.runner.prepare_and_validate_workspace
    end

    def environment
      application.environment
    end

    # Returns true if RGen is running in an application workspace
    def in_app_workspace?
      path = Pathname.new(Dir.pwd)
      until path.root? || File.exist?(File.join(path, APP_CONFIG))
        path = path.parent
      end
      !path.root?
    end

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
              fail 'Something went wrong resolving the application root!'
            end
            path
          end
        end
      end
    end
    alias_method :app_root, :root

    # Like RGen.root but this will return the plugin root if called by plugin code
    def root!
      file = caller[0]
      path = Pathname.new(file).dirname
      until path.root? || File.exist?(File.join(path, APP_CONFIG))
        path = path.parent
      end
      if path.root?
        fail "Something went wrong resolving RGen.root! from: #{caller[0]}"
      end
      path.realpath
    end

    # Ugly hack to force RGen.root references to the plugin's top-level when loading
    # the environment.rb of the plugin
    #
    # References to RGen.root in a plugin environment.rb is deprecated and this will be
    # removed in future once all plugins load through bundler
    #
    # @api private
    def with_rgen_root(path)
      orig = app.root
      @root_fudge_active = true
      app.root = Pathname.new(path)
      yield
      app.root = orig
      @root_fudge_active = false
    end

    # Turns off bundler and all plugins if the app is loaded within this block
    # @api private
    def with_boot_environment
      @with_boot_environment = true
      yield
      @with_boot_environment = false
    end

    def with_disable_rgen_version_check(*args, &block)
      version_checker.with_disable_rgen_version_check(*args, &block)
    end
    alias_method :disable_rgen_version_check, :with_disable_rgen_version_check

    # This is the application-facing API for implementing custom callbacks,
    # the top-level application, all plugin application instances, and any
    # application objects that include the RGen::Callbacks module will be
    # returned
    #
    # RGen system callbacks should use RGen.app.listeners_for instead, that
    # version will return only the current plugin instance instead of them all
    # (yes we need to make the API more obvious).
    def listeners_for(*args)
      callback = args.shift
      max = args.first.is_a?(Numeric) ? args.shift : nil
      listeners = [RGen.app] + RGen.plugins +
                  RGen.app.instantiated_callback_listeners
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
      @import_manager ||= ImportManager.new
    end
    alias_method :imports_manager, :import_manager

    def plugins_manager
      application.plugins_manager
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
      @time ||= RGen::Tester::Time.new
    end

    def controllers
      @controllers ||= []
    end

    def version(options = {})
      @version = nil if options[:refresh]
      return @version if @version && !options[:refresh]
      if options[:refresh] || !defined?(RGen::VERSION)
        load File.join(Pathname.new(File.dirname(__FILE__)).parent, 'config', 'version.rb')
      end
      @version = RGen::VersionString.new(RGen::VERSION)
    end

    # Loads the top-level application and all of its plugins, but not the target
    #
    # In most cases this should never need to be called directly and will be called
    # automatically the first time the application is referenced via RGen.app
    def load_application(check_version = true)
      @application ||= begin
        # This flag is set so that when a thread starts with no app it remains with no app. This
        # was an issue when building a new app with the fetch command and when the thread did a
        # chdir to the new app directory (to fetch it) RGen.log would try to load the partial app.
        @running_outside_an_app = true unless in_app_workspace?
        return nil if @running_outside_an_app
        require File.join(root, APP_CONFIG)
        @application = _applications_lookup[:root][root.to_s]
        if File.exist?(File.join(root, 'Gemfile')) && !@with_boot_environment
          # Don't understand the rules here, belt and braces approach for now to make
          # sure that all RGen plugins are auto-required (otherwise RGen won't know
          # about them to plug them into the application)
          Bundler.require
          Bundler.require(:development)
          Bundler.require(:runtime)
          Bundler.require(:default)
        end
        if @with_boot_environment
          @application.current_plugin.disable
        else
          RGen.import_manager.require!
          RGen.remote_manager.require!
        end
        env = File.join(root, 'config', 'environment.rb')
        require env if File.exist?(env)
        dev = File.join(root, 'config', 'development.rb')
        require dev if File.exist?(dev)
        version_checker.check! if check_version
        validate_rgen_dev_configuration!
        ([@application] + RGen.plugins).each(&:on_loaded)
        @application_loaded = true
        @application
      end
    end

    def launch_time
      @launch_time ||= time_now
    end

    # Returns an instance of RGen::VersionChecker
    def version_checker
      @version_checker ||= VersionChecker.new
    end

    # Returns the full path to the RGen core top-level directory
    def top
      @rgen_top ||= Pathname.new(File.dirname(__FILE__)).parent
    end

    # Compile the given file and return the result as a string
    def compile(file, options = {})
      RGen::Generator::Compiler.new.compile_inline(file, options)
    end

    def vault
      VAULT
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
      if options[:interface] && !RGen.tester.doc?
        @interface = eval(options[:interface]).new(options)
      else
        int = interfaces.find { |i| i.supports?(RGen.tester) }
        if int
          @interface = int.new(options)
        else
          unless options.delete(:silence_no_interface_error)
            fail "No interface has been defined for tester: #{RGen.tester.class}"
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
    def current_user
      if app_loaded? || in_app_workspace?
        application.current_user
      else
        User.new(User.current_user_id)
      end
    end

    def lsf
      application.lsf_manager
    end

    def running_on_windows?
      RUBY_PLATFORM == 'i386-mingw32'
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

    # Returns true if RGen is running with the -d or --debug switches enabled
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
      # This should be integrated with RGen.config.mode in the future
      @development
    end

    def set_development_mode
      @development = true
    end

    # Returns an object tracking the RGen execution mode/configuration, an
    # instance of RGen::Mode
    def mode
      application.config.mode
    end

    def mode=(val)
      application.config.mode = val
    end

    # Returns the current top-level (DUT) object if one has been defined (by
    # instantiating an object that includes RGen::TopLevel).
    def top_level
      # TODO: This is called a lot and should probably be cached and expired
      # on before_target_load
      application.top_level
    end

    def deprecate(*msgs)
      _deprecate(*msgs)
      if RGen.app
        # If an app deprecation return the caller who called the deprecated method
        if caller[0] =~ /#{RGen.root}/
          c = caller[1]
        # If an RGen deprecation then return the first caller from the current app
        else
          c = caller.find { |line| line =~ /#{RGen.root}/ }
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

    # Returns the name of the currently executing RGen command (a String),
    # e.g. 'generate', 'program', 'compile', etc.
    def current_command
      @current_command
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
# that is included whenever rspec (or another 3rd party) loads RGen
# outside the scope of an RGen command
require 'rgen/global_methods'
include RGen::GlobalMethods
