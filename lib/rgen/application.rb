module RGen
  # In RGen v2 this class was introduced to formally co-ordinate application level
  # configuration of RGen.
  #
  # == Configuration
  #
  # See RGen::Application::Configuration for the available options.
  class Application
    autoload :Configuration, 'rgen/application/configuration'
    autoload :Target,        'rgen/application/target'
    autoload :Environment,   'rgen/application/environment'
    autoload :PluginsManager, 'rgen/application/plugins_manager'
    autoload :LSF,           'rgen/application/lsf'
    autoload :Runner,        'rgen/application/runner'
    autoload :ConfigurationManager, 'rgen/application/configuration_manager'
    autoload :LSFManager,    'rgen/application/lsf_manager'
    autoload :Release,       'rgen/application/release'
    autoload :Deployer,      'rgen/application/deployer'
    autoload :VersionTracker, 'rgen/application/version_tracker'
    autoload :CommandDispatcher, 'rgen/application/command_dispatcher'
    autoload :WorkspaceManager, 'rgen/application/workspace_manager'

    require 'rgen/users'
    include RGen::Users

    attr_accessor :current_job
    attr_accessor :name
    attr_accessor :namespace

    class << self
      def inherited(base)
        # Somehow using the old import system and version file format we can get in here when
        # loading the version, this can be removed in future when the imports API is retired
        unless caller[0] =~ /version.rb.*/
          root = Pathname.new(caller[0].sub(/(\\|\/)?config(\\|\/)application.rb.*/, '')).realpath
          app = base.instance
          app.root = root.to_s
          RGen.register_application(app)
          app.add_lib_to_load_path!
        end
      end

      def instance
        @instance ||= new
      end

      def respond_to?(*args)
        super || instance.respond_to?(*args)
      end

      protected

      def method_missing(*args, &block)
        instance.send(*args, &block)
      end
    end

    # A simple class to load all rake tasks available to an application, a class is used here
    # to avoid collision with the Rake namespace method
    class RakeLoader
      require 'rake'
      include Rake::DSL

      def load_tasks
        $VERBOSE = nil  # Don't care about world writable dir warnings and the like
        require 'colored'

        # Load all RGen tasks first
        Dir.glob("#{RGen.top}/lib/tasks/*.rake").sort.each do |file|
          load file
        end
        # Now the application's own tasks
        if RGen.app.rgen_core?
          Dir.glob("#{RGen.root}/lib/tasks/private/*.rake").sort.each do |file|
            load file
          end
        else
          Dir.glob("#{RGen.root}/lib/tasks/*.rake").sort.each do |file|
            load file
          end
        end
        # Finally those that the plugin's have given us
        ([RGen.app] + RGen.plugins).each do |plugin|
          namespace plugin.name do
            Dir.glob("#{plugin.root}/lib/tasks/shared/*.rake").sort.each do |file|
              load file
            end
          end
        end
      end
    end

    # Load all rake tasks defined in the application's lib/task directory
    def load_tasks
      RakeLoader.new.load_tasks
    end

    # Returns
    def revision_controller
      if current?
        if config.rc_url
          if config.rc_url =~ /^sync:/
            @revision_controller ||= RevisionControl::DesignSync.new(
              local:  root,
              remote: config.rc_url
            )
          elsif config.rc_url =~ /git/
            @revision_controller ||= RevisionControl::Git.new(
              local:  root,
              remote: config.rc_url
            )
          else
            fail "The revision control type could not be worked out from the value config.rc_url: #{config.rc_url}"
          end
        else
          @revision_controller ||= RevisionControl::DesignSync.new(
            local:  root,
            remote: config.vault
          )
        end
      else
        fail "Only the top-level application has a revision controller! #{name} is a plugin"
      end
    end
    alias_method :rc, :revision_controller

    # This callback handler will fire once the main app and all of its plugins have been loaded
    def on_loaded
      config.log_deprecations
    end

    # Convenience method to check if the given application instance is RGen core
    def rgen_core?
      name.to_s.symbolize == :rgen_core
    end

    def inspect
      "<RGen app (#{name}):#{object_id}>"
    end

    def root=(val)
      @root = Pathname.new(val)
    end

    def require_environment!
      RGen.deprecate 'Calling app.require_environment! is no longer required, the app environment is now automtically loaded when RGen.app is called'
    end

    # Returns a full path to the root directory of the given application
    #
    # If the application instance is a plugin then this will point to where
    # the application is installed within the imports directory
    def root
      @root
    end

    # Returns the namespace used by the application as a string
    def namespace
      @namespace ||= self.class.to_s.split('::').first.gsub('_', '').sub('Application', '')
    end

    # Returns an array of users who have subscribed for production release
    # notifications for the given application on the website
    def subscribers_prod
      if server_data
        @subscribers_prod ||= server_data[:subscribers_prod].map { |u| User.new(u[:core_id]) }
      else
        []
      end
    end

    # Returns an array of users who have subscribed for development release
    # notifications for the given application on the website
    def subscribers_dev
      if server_data
        @subscribers_dev ||= server_data[:subscribers_dev].map { |u| User.new(u[:core_id]) }
      else
        []
      end
    end

    # Returns the server data packet available for the given application,
    # returns nil if none is found
    def server_data
      if name == :rgen
        @server_data ||= RGen.client.rgen
      else
        @server_data ||= RGen.client.plugins.find { |p| p[:rgen_name].downcase == name.to_s.downcase }
      end
    end

    # Returns true if the given application instance is the
    # current top level application
    def current?
      RGen.app == self
    end

    # Returns true if the given application instance is
    # the current plugin
    def current_plugin?
      if RGen.current_plugin.name
        RGen.current_plugin.instance == self
      else
        false
      end
    end

    # Returns the current top-level object (the DUT)
    def top_level
      toplevel_listeners.first
    end

    def listeners_for(*args)
      callback = args.shift
      max = args.first.is_a?(Numeric) ? args.shift : nil
      options = args.shift || {}
      options = {
        top_level: :first
      }.merge(options)
      listeners = callback_listeners
      if RGen.top_level
        listeners -= [RGen.top_level]
        if options[:top_level]
          if options[:top_level] == :last
            listeners = listeners + [RGen.top_level]
          else
            listeners = [RGen.top_level] + listeners
          end
        end
      end
      listeners = listeners.select { |l| l.respond_to?(callback) }
      if max && listeners.size > max
        fail "You can only define a #{callback} callback #{max > 1 ? (max.to_s + 'times') : 'once'}, however you have declared it #{listeners.size} times for instances of: #{listeners.map(&:class)}"
      end
      listeners
    end

    def version(options = {})
      @version = nil if options[:refresh]
      return @version if @version
      load File.join(root, 'config', 'version.rb')
      if defined? eval(namespace)::VERSION
        @version = RGen::VersionString.new(eval(namespace)::VERSION)
      else
        # The eval of the class is required here as somehow when plugins are imported under the old
        # imports system and with the old version file format we can end up with two copies of the
        # same class constant. Don't understand it, but it is fixed with the move to gems and the
        # namespace-based version file format.
        @version = RGen::VersionString.new(eval(self.class.to_s)::VERSION)
      end
      @version
    end

    # Returns the release note for the current or given application version
    def release_note(version = RGen.app.version.prefixed)
      version = VersionString.new(version)
      version = version.prefixed if version.semantic?
      capture = false
      note_started = false
      note = []
      File.readlines("#{RGen.root}/doc/history").each do |line|
        line = line.strip
        if capture
          if note_started
            if line =~ /^<a class="anchor release_tag/ || line =~ /^#+ Tag/
              note.pop while note.last && note.last.empty?
              return note
            end
            if line.empty? && note.empty?
              # Don't capture preceding blank lines
            else
              note << line
            end
          elsif line =~ /^#+ by/
            note_started = true
          end
        else
          if line =~ /Tag:/
            line = line.gsub('\\', '')
            if line =~ /^#+ Tag: #{version}$/ ||
               line =~ />Tag: #{version}</
              capture = true
            end
          end
        end
      end
      note.pop while note.last && note.last.empty?
      note
    end

    # Returns the release date for the current or given application version
    def release_date(version = RGen.app.version.prefixed)
      time = release_time(version)
      time ? time.to_date : nil
    end

    # Returns the release time for the current or given application version
    def release_time(version = RGen.app.version.prefixed)
      version = VersionString.new(version)
      version = version.prefixed if version.semantic?
      capture = false
      File.readlines("#{RGen.root}/doc/history").each do |line|
        line = line.strip
        if capture
          if capture && line =~ /^#+ by .* on (.*(AM|PM))/
            return Time.parse(Regexp.last_match(1))
          end
        else
          if line =~ /Tag:/
            line = line.gsub('\\', '')
            if line =~ /^#+ Tag: #{version}$/ ||
               line =~ />Tag: #{version}</
              capture = true
            end
          end
        end
      end
      nil
    end

    # Returns the author (committer) for the current or given application version
    #
    # If the user can be found in the directory then a user object will be returned,
    # otherwise the name will be returned as a String
    def author(version = RGen.app.version.prefixed)
      version = VersionString.new(version)
      version = version.prefixed if version.semantic?
      capture = false
      File.readlines("#{RGen.root}/doc/history").each do |line|
        line = line.strip
        if capture
          if capture && line =~ /^#+ by (.*) on (.*(AM|PM))/
            user = RGen.fsl.find_by_name(Regexp.last_match(1))
            return user if user
            return Regexp.last_match(1)
          end
        else
          if line =~ /Tag:/
            line = line.gsub('\\', '')
            if line =~ /^#+ Tag: #{version}$/ ||
               line =~ />Tag: #{version}</
              capture = true
            end
          end
        end
      end
      nil
    end

    # Returns the branch for the current or given application version
    def branch(version = RGen.app.version.prefixed)
      version = VersionString.new(version)
      version = version.prefixed if version.semantic?
      capture = false
      File.readlines("#{RGen.root}/doc/history").each do |line|
        line = line.strip
        if capture
          if capture && line =~ /^#+ .*(Selector|Branch): '(.*)'/
            return Regexp.last_match(2).gsub('\\', '')
          end
        else
          if line =~ /Tag:/
            line = line.gsub('\\', '')
            if line =~ /^#+ Tag: #{version}$/ ||
               line =~ />Tag: #{version}</
              capture = true
            end
          end
        end
      end
      nil
    end
    alias_method :selector, :branch

    def previous_versions
      versions = []
      File.readlines("#{RGen.root}/doc/history").each do |line|
        line = line.strip
        if line =~ /^#+ Tag: (.*)$/ ||
           line =~ />Tag: ([^<]*)</
          versions << Regexp.last_match(1).gsub('\\', '')
        end
      end
      versions.uniq
    end

    def contributors
      c = []
      File.readlines("#{RGen.root}/doc/history").each do |line|
        if line =~ /^#+ by (.*) on /
          c << Regexp.last_match(1)
        end
      end
      c.uniq
    end

    def config
      @config ||= Configuration.new(self)
    end

    # Returns the name of the given application, this is the name that will
    # be used to refer to the application when it is used as a plugin
    def name
      (@name ||= namespace).to_s.underscore.symbolize
    end

    def plugins_manager
      @plugins_manager ||= PluginsManager.new
    end
    alias_method :plugin_manager, :plugins_manager
    alias_method :current_plugin, :plugins_manager

    def target
      @target ||= Target.new
    end

    def environment
      @environment ||= Environment.new
    end

    def lsf
      @lsf ||= LSF.new
    end

    def runner
      @runner ||= Runner.new
    end

    def deployer
      @deployer ||= Deployer.new
    end

    def lsf_manager
      @lsf_manager ||= LSFManager.new
    end

    def version_tracker
      @version_tracker ||= VersionTracker.new
    end

    def workspace_manager
      @workspace_manager ||= WorkspaceManager.new
    end

    def mailer
      @mailer ||= Utility::Mailer.new
    end

    def db
      @db ||= Database::KeyValueStores.new(self)
    end

    def session
      @session ||= Database::KeyValueStores.new(self, persist: false)
    end

    def pdm_component
      return @pdm_component if @pdm_component
      require "#{RGen.root}/config/pdm_component"
      begin
        @pdm_component = (eval "#{RGen.app.class}::PDMComponent").new
      rescue
        # Try legacy case where the namespace was just Application
        @pdm_component = ::Application::PDMComponent.new
      end
    end

    def versions
      version_tracker.versions
    end

    def release(options)
      @release ||= Release.new
      @release.run(options)
    end

    def statistics
      runner.statistics
    end
    alias_method :stats, :statistics

    def configuration_manager
      @cm ||= ConfigurationManager.new
    end
    alias_method :cm, :configuration_manager

    def pattern_iterators
      @pattern_iterators ||= []
    end

    def callback_listeners
      current = RGen.current_plugin.instance
      applications = [self]
      applications << current if current
      applications + instantiated_callback_listeners
    end

    def instantiated_callback_listeners
      dynamic_resource(:callback_listeners, []) + (@persistant_callback_listeners || [])
    end

    def toplevel_listeners
      dynamic_resource(:toplevel_listeners, [])
    end

    def add_callback_listener(obj)
      dynamic_resource(:callback_listeners, [], adding: true) << obj
    end

    def add_persistant_callback_listener(obj)
      @persistant_callback_listeners ||= []
      @persistant_callback_listeners << obj
      @persistant_callback_listeners.uniq!
    end

    def add_toplevel_listener(obj)
      if RGen.top_level
        puts "Attempt to set an instance of #{obj.class} as the top level when there is already an instance of #{RGen.top_level.class} defined as the top-level!"
        fail 'Only one object that include the RGen::TopLevel module can be instantiated per target!'
      end
      $dut = obj
      dynamic_resource(:toplevel_listeners, [], adding: true) << obj
    end

    # Any attempts to instantiate a test within the give block will be forced to instantiate
    # an RGen::Tester::Doc instance
    def with_doc_tester(options = {})
      @with_doc_tester = true
      if options[:html]
        @with_html_doc_tester = true
      end
      yield
      @with_doc_tester = false
      @with_html_doc_tester = false
    end

    def with_doc_tester?
      @with_doc_tester
    end

    def with_html_doc_tester?
      @with_html_doc_tester
    end

    def tester
      dynamic_resource(:tester, []).first
    end

    def tester=(obj)
      # if tester && obj
      #  raise "You can only instantiate 1 tester, you have already created an instance of #{tester.class}}"
      # end
      set_dynamic_resource(:tester, [obj])
    end

    def pin_map
      dynamic_resource(:pin_map, {})
    end

    def add_pin_to_pin_map(id, pin)
      # If being added during target load...
      if @load_event
        pin_map[id] = pin
      # Being added late in the process...
      else
        @transient_resources[:pin_map][id] = pin
      end
    end

    def pingroup_map
      dynamic_resource(:pingroup_map, {})
    end

    def add_pingroup_to_pingroup_map(id, pins)
      # If being added during target load...
      if @load_event
        pingroup_map[id] = pins
      # Being added late in the process...
      else
        @transient_resources[:pingroup_map][id] = pins
      end
    end

    def pin_pattern_order
      if @load_event
        dynamic_resource(:pin_pattern_order, [])
      else
        @transient_resources[:pin_pattern_order] ||= []
      end
    end

    def pin_pattern_exclude
      if @load_event
        dynamic_resource(:pin_pattern_exclude, [])
      else
        @transient_resources[:pin_pattern_exclude] ||= []
      end
    end

    def pin_names
      if @load_event
        dynamic_resource(:pin_names, {})
      else
        @transient_resources[:pin_names] ||= {}
      end
    end

    def load_console
      load_target!
    end

    def load_target!(options = {})
      options = {
        force_debug: false
      }.merge(options)
      if options[:reload]
        @target_load_count = 0
      else
        @target_load_count ||= 0
        @target_load_count += 1
      end
      listeners_for(:before_load_target).each(&:before_load_target)
      # Remember these if the target has to be reloaded
      @target_load_options = options.merge({})
      # Since this is a load it will re-instantiate any objects that the application
      # declares here, the objects registered with rgen should be refreshed accordingly
      clear_dynamic_resources
      load_event(:transient) do
        RGen.config.mode = :production  # Important since a production target may rely on the default
        begin
          $_target_options = @target_load_options
          RGen.target.set_signature(@target_load_options)
          $dut = nil
          load environment.file if environment.file
          load target.file!
        ensure
          $_target_options = nil
        end
        @target_instantiated = true
        RGen.config.mode = :debug if options[:force_debug]
        listeners_for(:on_create).each(&:on_create)
        # Keep this within the load_event to ensure any objects that are further instantiated objects
        # will be associated with (and cleared out upon reload of) the current target
        listeners_for(:on_load_target).each(&:on_load_target)
      end
      listeners_for(:after_load_target).each(&:after_load_target)
      RGen.import_manager.validate_production_status
      # @target_instantiated = true
    end

    # Not a clean unload, but allows objects to be re-instantiated for testing
    # @api private
    def unload_target!
      listeners_for(:before_load_target).each(&:before_load_target)
      clear_dynamic_resources
      clear_dynamic_resources(:static)
      RGen::Pins.clear_pin_aliases
      $dut = nil
    end

    # Equivalent to load_target! except that any options that were passed
    # to load_target! the last time it was called will be re-applied when
    # (re)loading the target.
    def reload_target!(options = {})
      old_options = @target_load_options || {}
      options = (@target_load_options || {}).merge(options)
      if options[:skip_first_time] && @target_load_count == 1
        @target_load_count += 1
      else
        load_target!(options.merge(reload: true))
      end
    end

    def set_dynamic_resource(name, value)
      dynamic_resource(name, value, set: true)
    end

    # Enable for debugging to see what the currently tracked objects are
    # def object_store
    #  [@load_event, @static_resources, @transient_resources]
    # end

    def dynamic_resource(name, default, options = {})
      @static_resources ||= {}
      @transient_resources ||= {}
      if @load_event == :static ||
         (!@load_event && options[:adding])
        if options[:set]
          @static_resources[name] = default
        else
          @static_resources[name] ||= default
        end
      elsif @load_event == :transient
        if options[:set]
          @transient_resources[name] = default
        else
          @transient_resources[name] ||= default
        end
      else
        static = @static_resources[name] ||= default
        transient = @transient_resources[name] ||= default
        if static.respond_to?('+')
          static + transient
        else
          static.merge(transient)
        end
      end
    end

    def clear_dynamic_resources(type = :transient)
      if type == :transient
        @transient_resources = nil
      else
        @static_resources = nil
      end
    end

    def load_event(type)
      @load_event = type
      yield
      @load_event = nil
    end

    def target_instantiated?
      @target_instantiated
    end

    # This method is called just after an application inherits from RGen::Application,
    # allowing the developer to load classes in lib and use them during application
    # configuration.
    #
    #   class MyApplication < RGen::Application
    #     require "my_backend" # in lib/my_backend
    #     config.i18n.backend = MyBackend
    #   end
    def add_lib_to_load_path! #:nodoc:
      [root.join('lib'), root.join('vendor', 'lib')].each do |path|
        $LOAD_PATH.unshift(path.to_s) if File.exist?(path) && !$LOAD_PATH.include?(path.to_s)
      end
    end
  end
end
