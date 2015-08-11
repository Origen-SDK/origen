require 'English'
require 'pathname'
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
require 'origen/import_manager'
require 'origen/remote_manager'
require 'origen/utility'
require 'origen/version_checker'
require 'origen/logger_methods'
require 'option_parser/optparse'
require 'bundler'

module Origen
  autoload :Features,  'origen/features'
  autoload :Bugs,      'origen/bugs'
  autoload :Generator, 'origen/generator'
  autoload :Pins,      'origen/pins'
  autoload :Registers, 'origen/registers'
  autoload :Tester,    'origen/tester'
  autoload :Users,     'origen/users'
  autoload :FileHandler, 'origen/file_handler'
  autoload :RegressionManager, 'origen/regression_manager'
  autoload :NVM,       'origen/nvm'
  autoload :Location,  'origen/location'
  autoload :VersionString, 'origen/version_string'
  autoload :Mode,      'origen/mode'
  autoload :ChipMode,   'origen/chip_mode'
  autoload :ChipPackage,   'origen/chip_package'
  autoload :Client,    'origen/client'
  autoload :SubBlocks,  'origen/sub_blocks'
  autoload :SubBlock,   'origen/sub_blocks'
  autoload :ModelInitializer,  'origen/model_initializer'
  autoload :Controller, 'origen/controller'
  autoload :Database,   'origen/database'
  autoload :Parameters, 'origen/parameters'
  autoload :RevisionControl, 'origen/revision_control'
  autoload :Specs,      'origen/specs'
  autoload :CodeGenerators, 'origen/code_generators'
  autoload :Encodings, 'origen/encodings'
  autoload :Log,       'origen/log'

  APP_CONFIG = File.join('config', 'application.rb')

  class OrigenError < StandardError
    def self.status_code(code)
      define_method(:status_code) { code }
    end
  end

  class GitError < OrigenError; status_code(11); end
  class DesignSyncError < OrigenError; status_code(12); end

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

    # Returns an array containing the application instances of all plugins
    def plugins
      @plugins ||= begin
        top = Origen.app
        plugins = []
        Origen._applications_lookup[:name].each do |_name, app|
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

    def load_target(t, options = {})
      target.temporary = t
      application.load_target!(options)
      application.runner.prepare_and_validate_workspace
    end

    def environment
      application.environment
    end

    # Returns true if Origen is running in an application workspace
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

    # Turns off bundler and all plugins if the app is loaded within this block
    # @api private
    def with_boot_environment
      @with_boot_environment = true
      yield
      @with_boot_environment = false
    end

    def with_disable_origen_version_check(*args, &block)
      version_checker.with_disable_origen_version_check(*args, &block)
    end
    alias_method :disable_origen_version_check, :with_disable_origen_version_check

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
      listeners = [Origen.app] + Origen.plugins +
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
    def load_application(check_version = true)
      @application ||= begin
        # This flag is set so that when a thread starts with no app it remains with no app. This
        # was an issue when building a new app with the fetch command and when the thread did a
        # chdir to the new app directory (to fetch it) Origen.log would try to load the partial app.
        @running_outside_an_app = true unless in_app_workspace?
        return nil if @running_outside_an_app
        require File.join(root, APP_CONFIG)
        @application = _applications_lookup[:root][root.to_s]
        if File.exist?(File.join(root, 'Gemfile')) && !@with_boot_environment
          # Don't understand the rules here, belt and braces approach for now to make
          # sure that all Origen plugins are auto-required (otherwise Origen won't know
          # about them to plug them into the application)
          Bundler.require
          Bundler.require(:development)
          Bundler.require(:runtime)
          Bundler.require(:default)
        end
        if @with_boot_environment
          @application.current_plugin.disable
        else
          Origen.import_manager.require!
          Origen.remote_manager.require!
        end
        env = File.join(root, 'config', 'environment.rb')
        require env if File.exist?(env)
        dev = File.join(root, 'config', 'development.rb')
        require dev if File.exist?(dev)
        version_checker.check! if check_version
        validate_origen_dev_configuration!
        ([@application] + Origen.plugins).each(&:on_loaded)
        @application_loaded = true
        @application
      end
    end

    def launch_time
      @launch_time ||= time_now
    end

    # Returns an instance of Origen::VersionChecker
    def version_checker
      @version_checker ||= VersionChecker.new
    end

    # Returns the full path to the Origen core top-level directory
    def top
      @origen_top ||= Pathname.new(File.dirname(__FILE__)).parent
    end

    # Compile the given file and return the result as a string
    def compile(file, options = {})
      Origen::Generator::Compiler.new.compile_inline(file, options)
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
          unless options.delete(:silence_no_interface_error)
            fail "No interface has been defined for tester: #{Origen.tester.class}"
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
      application.config.mode
    end

    def mode=(val)
      application.config.mode = val
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
