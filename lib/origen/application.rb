module Origen
  # In Origen v2 this class was introduced to formally co-ordinate application level
  # configuration of Origen.
  #
  # == Configuration
  #
  # See Origen::Application::Configuration for the available options.
  class Application
    autoload :Configuration, 'origen/application/configuration'
    autoload :Target,        'origen/application/target'
    autoload :Environment,   'origen/application/environment'
    autoload :PluginsManager, 'origen/application/plugins_manager'
    autoload :Plugins,       'origen/application/plugins'
    autoload :LSF,           'origen/application/lsf'
    autoload :Runner,        'origen/application/runner'
    autoload :LSFManager,    'origen/application/lsf_manager'
    autoload :Release,       'origen/application/release'
    autoload :Deployer,      'origen/application/deployer'
    autoload :VersionTracker, 'origen/application/version_tracker'
    autoload :CommandDispatcher, 'origen/application/command_dispatcher'
    autoload :WorkspaceManager, 'origen/application/workspace_manager'

    require 'origen/users'
    include Origen::Users

    attr_accessor :name
    attr_accessor :namespace

    class << self
      def inherited(base)
        # Somehow using the old import system and version file format we can get in here when
        # loading the version, this can be removed in future when the imports API is retired
        unless caller[0] =~ /version.rb.*/
          if base.to_s == 'OrigenGlobalApplication'
            app = base.instance
            app.root = Origen.root
            Origen.register_application(app)
          else
            root = Pathname.new(caller[0].sub(/(\\|\/)?config(\\|\/)application.rb.*/, '')).realpath
            app = base.instance
            app.root = root.to_s
            if Origen.plugins_loaded? && !Origen.loading_top_level?
              # This situation of a plugin being loaded after the top-level app could occur if the app
              # doesn't require the plugin until later, in that case there is nothing the plugin owner
              # can do and we just need to accept that this can happen.
              # Origen.log.warning "The #{app.name} plugin is using a non-standard loading mechanism, upgrade to a newer version of it to get rid of this warning (please report a bug to its owner if this warning persists)"
              Origen.register_application(app)
              # Origen.app.plugins << app
            else
              Origen.register_application(app)
            end
            app.add_lib_to_load_path!
            # Also blow this cache as a new app has just been added
            @apps_by_namespace = nil
          end
        end
      end

      def instance
        @instance ||= new
      end

      def respond_to?(*args)
        super || instance.respond_to?(*args)
      end

      # Returns the application instance (i.e. main app or the plugin) that owns the given class/module
      # (literal, string or symbol representation is accepted) or object instance.
      # Returns nil if no matching Origen application can be found.
      #
      #     Origen::Application.from_namespace(MyApp)                       # => <my_app instance>
      #     Origen::Application.from_namespace(MyApp::MyClass)              # => <my_app instance>
      #     Origen::Application.from_namespace('MyApp::MyClass')            # => <my_app instance>
      #     Origen::Application.from_namespace(<my_app::my_class instance>) # => <my_app instance>
      def from_namespace(item)
        unless item.is_a?(String)
          if item.is_a?(Module) || item.is_a?(Class) || item.is_a?(Symbol)
            item = item.to_s
          else # Assume to be an object instance in this case
            item = item.class.to_s
          end
        end
        namespace = item.split('::').first
        @apps_by_namespace ||= {}
        @apps_by_namespace[namespace] ||= begin
          return Origen.app if Origen.app.namespace == namespace

          Origen.app.plugins.each do |plugin|
            return plugin if plugin.namespace == namespace
          end
          nil
        end
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
        $VERBOSE = nil # Don't care about world writable dir warnings and the like
        require 'colored'

        # Load all Origen tasks first
        Dir.glob("#{Origen.top}/lib/tasks/*.rake").sort.each do |file|
          load file
        end
        # Now the application's own tasks
        if Origen.app.origen_core?
          Dir.glob("#{Origen.root}/lib/tasks/private/*.rake").sort.each do |file|
            load file
          end
        else
          # New application dir structure support
          Dir.glob("#{Origen.root}/app/lib/tasks/*.rake").sort.each do |file|
            load file
          end

          Dir.glob("#{Origen.root}/lib/tasks/*.rake").sort.each do |file|
            load file
          end
        end
        # Finally those that the plugin's have given us
        ([Origen.app] + Origen.app.plugins).each do |plugin|
          namespace plugin.name do
            # New application dir structure support
            Dir.glob("#{plugin.root}/app/lib/tasks/shared/*.rake").sort.each do |file|
              load file
            end

            Dir.glob("#{plugin.root}/lib/tasks/shared/*.rake").sort.each do |file|
              load file
            end
          end
        end
      end
    end

    # @api private
    #
    # Returns a lookup table for all block definitions (app/blocks) that the app contains
    def blocks_files
      @blocks_files ||= begin
        files = {}
        block_dir = Pathname.new(File.join(root, 'app', 'blocks'))
        if block_dir.exist?
          block_dir.children.each do |item|
            if item.directory?
              _add_block_files(files, block_dir, item)
            end
          end
        end
        files
      end
    end

    # @api private
    def _add_block_files(files, block_dir, current_dir, sub_block = false)
      fields = current_dir.relative_path_from(block_dir).to_s.split('/')
      fields.delete('derivatives')
      fields.delete('sub_blocks')
      path = fields.join('/')
      files[path] ||= {}
      files[path][:_sub_block] = true if sub_block
      Dir.glob(current_dir.join('*.rb')).each do |file|
        file = Pathname.new(file)
        type = file.basename('.rb').to_s.to_sym
        unless type == :model || type == :controller
          files[path][type] ||= []
          files[path][type] << file.to_s
        end
      end
      derivatives = current_dir.join('derivatives')
      if derivatives.exist?
        derivatives.children.each do |item|
          if item.directory?
            _add_block_files(files, block_dir, item)
          end
        end
      end
      sub_blocks = current_dir.join('sub_blocks')
      if sub_blocks.exist?
        sub_blocks.children.each do |item|
          if item.directory?
            _add_block_files(files, block_dir, item, true)
          end
        end
      end
    end

    def current_job
      current_jobs.last
    end

    def current_jobs
      @current_jobs ||= []
    end

    # Load all rake tasks defined in the application's lib/task directory
    def load_tasks
      RakeLoader.new.load_tasks
    end

    # Returns a revision controller instance (e.g. Origen::RevisionControl::Git) which has
    # been configured to point to the local workspace and the remote repository
    # as defined by Origen.app.config.rc_url. If the revision control URL has not been
    # defined, or it does not resolve to a recognized revision control system, then this
    # method will return nil.
    def revision_controller(options = {})
      if current?
        if config.rc_url
          begin
            if config.rc_url =~ /^sync:/
              @revision_controller ||= RevisionControl::DesignSync.new(
                local: root,
                remote: config.rc_url
              )
            elsif config.rc_url =~ /git/
              @revision_controller ||= RevisionControl::Git.new(
                local: root,
                # If a workspace is based on a fork of the master repo, config.rc_url may not
                # be correct
                remote: (options[:uninitialized] ? config.rc_url : (RevisionControl::Git.origin || config.rc_url)),
                allow_local_adjustment: true
              )

            end
          # The rc_url has been defined, but the initial app checkin has not been done yet
          rescue RevisionControlUninitializedError
            @revision_controller = nil
          end
        elsif config.vault
          @revision_controller ||= RevisionControl::DesignSync.new(
            local: root,
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

    # Convenience method to check if the given application instance is Origen core
    def origen_core?
      name.to_s.symbolize == :origen_core
    end

    def inspect
      "<Origen app (#{name}):#{object_id}>"
    end

    def root=(val)
      @root = Pathname.new(val)
    end

    def require_environment!
      Origen.deprecate 'Calling app.require_environment! is no longer required, the app environment is now automtically loaded when Origen.app is called'
    end

    # Returns a full path to the root directory of the given application
    #
    # If the application instance is a plugin then this will point to where
    # the application is installed within the imports directory
    def root
      @root
    end

    # Returns a path to the imports directory (e.g. used by the remotes and similar features) for the
    # application. e.g. if the app live at /home/thao/my_app, then the imports directory will typically
    # be /home/thao/.my_app_imports_DO_NOT_HAND_MODIFY
    #
    # Origen will ensure that this directory is outside of the scope of the current application's revision
    # control system. This prevents conflicts with the revision control system for the application and those
    # used to import 3rd party dependencies
    def imports_directory
      workspace_manager.imports_directory
    end
    alias_method :imports_dir, :imports_directory

    # Returns a path to the remotes directory for the application. e.g. if the app live
    # at /home/thao/my_app, then the remotes directory will typically
    # be /home/thao/.my_app_remotes_DO_NOT_HAND_MODIFY
    #
    # Origen will ensure that this directory is outside of the scope of the current application's revision
    # control system. This prevents conflicts with the revision control system for the application and those
    # used to import 3rd party dependencies
    def remotes_directory
      workspace_manager.remotes_directory
    end
    alias_method :remotes_dir, :remotes_directory

    # Returns the namespace used by the application as a string
    def namespace
      @namespace ||= self.class.to_s.split('::').first.gsub('_', '').sub('Application', '')
    end

    # Returns array of email addresses in the DEV maillist file
    def maillist_dev
      maillist_parse(maillist_dev_file)
    end

    # Returns array of email addresses in the PROD maillist file
    def maillist_prod
      maillist_parse(maillist_prod_file)
    end

    # Returns default location of DEV maillist file (customize locally if needed)
    def maillist_dev_file
      Origen.app.root.to_s + '/config/maillist_dev.txt'
    end

    # Returns default location of PROD maillist file (customize locally if needed)
    def maillist_prod_file
      Origen.app.root.to_s + '/config/maillist_prod.txt'
    end

    # Parses maillist file and returns an array of email address
    def maillist_parse(file)
      maillist = []

      # if file doesn't exist, just return empty array, otherwise, parse for emails
      if File.exist?(file)
        File.readlines(file).each do |line|
          if index = (line =~ /\#/)
            # line contains some kind of comment
            # check if there is any useful info, ignore it not
            unless line[0, index].strip.empty?
              maillist << Origen::Users::User.new(line[0, index].strip).email
            end
          else
            # if line is not empty, generate an email
            unless line.strip.empty?
              maillist << Origen::Users::User.new(line.strip).email
            end
          end
        end
      end
      maillist
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
      if name == :origen
        @server_data ||= Origen.client.origen
      else
        @server_data ||= Origen.client.plugins.find { |p| p[:origen_name].downcase == name.to_s.downcase }
      end
    end

    # Returns true if the given application instance is the
    # current top level application
    def current?
      # If this is called before the plugins are loaded (i.e. by a plugin's application file), then
      # it is definitely not the top-level app
      if Origen.application_loaded?
        Origen.app == self
      else
        Origen.root == root
      end
    end
    alias_method :standalone?, :current?
    alias_method :running_standalone?, :current?

    # Returns true if the given application instance is
    # the current plugin
    def current_plugin?
      if Origen.application_loaded?
        Origen.app.plugins.current == self
      else
        puts <<-END
current_plugin? cannot be used at this point in your code since the app is not loaded yet.

If you are calling this from config/application.rb then you can only use current_plugin? within a block:

# Not OK
if current_plugin?
  config.output_directory = "#{Origen.root}/output/dir1"
else
  config.output_directory = "#{Origen.root}/output/dir2"
end

# OK
config.output_directory do
  if current_plugin?
    "#{Origen.root}/output/dir1"
  else
    "#{Origen.root}/output/dir2"
  end
end

END
        exit 1
      end
    end

    # Returns the current top-level object (the DUT)
    def top_level
      @top_level ||= begin
        t = toplevel_listeners.first
        t.controller ? t.controller : t if t
      end
    end

    def listeners_for(*args)
      callback = args.shift
      max = args.first.is_a?(Numeric) ? args.shift : nil
      options = args.shift || {}
      options = {
        top_level: :first
      }.merge(options)
      listeners = callback_listeners
      if Origen.top_level
        listeners -= [Origen.top_level.model]
        if options[:top_level]
          if options[:top_level] == :last
            listeners = listeners + [Origen.top_level]
          else
            listeners = [Origen.top_level] + listeners
          end
        end
      end
      listeners = listeners.select { |l| l.respond_to?(callback) }.map do |l|
        if l.try(:is_an_origen_model?)
          l.respond_to_directly?(callback) ? l : l.controller
        else
          l
        end
      end
      if max && listeners.size > max
        fail "You can only define a #{callback} callback #{max > 1 ? (max.to_s + 'times') : 'once'}, however you have declared it #{listeners.size} times for instances of: #{listeners.map(&:class)}"
      end

      listeners
    end

    def version(options = {})
      @version = nil if options[:refresh]
      return @version if @version

      if Origen.running_globally?
        @version = Origen.version
      else
        load File.join(root, 'config', 'version.rb')
        if defined? eval(namespace)::VERSION
          @version = Origen::VersionString.new(eval(namespace)::VERSION)
        else
          # The eval of the class is required here as somehow when plugins are imported under the old
          # imports system and with the old version file format we can end up with two copies of the
          # same class constant. Don't understand it, but it is fixed with the move to gems and the
          # namespace-based version file format.
          @version = Origen::VersionString.new(eval(self.class.to_s)::VERSION)
        end
      end
      @version
    end

    # Returns the release note for the current or given application version
    def release_note(version = Origen.app.version.prefixed)
      version = VersionString.new(version)
      version = version.prefixed if version.semantic?
      capture = false
      note_started = false
      note = []
      File.readlines("#{Origen.root}/doc/history").each do |line|
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
    def release_date(version = Origen.app.version.prefixed)
      time = release_time(version)
      time ? time.to_date : nil
    end

    # Returns the release time for the current or given application version
    def release_time(version = Origen.app.version.prefixed)
      version = VersionString.new(version)
      version = version.prefixed if version.semantic?
      capture = false
      File.readlines("#{Origen.root}/doc/history").each do |line|
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
    def author(version = Origen.app.version.prefixed)
      version = VersionString.new(version)
      version = version.prefixed if version.semantic?
      capture = false
      File.readlines("#{Origen.root}/doc/history").each do |line|
        line = line.strip
        if capture
          if capture && line =~ /^#+ by (.*) on (.*(AM|PM))/
            user = Origen.fsl.find_by_name(Regexp.last_match(1))
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
    def branch(version = Origen.app.version.prefixed)
      version = VersionString.new(version)
      version = version.prefixed if version.semantic?
      capture = false
      File.readlines("#{Origen.root}/doc/history").each do |line|
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
      File.readlines("#{Origen.root}/doc/history").each do |line|
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
      File.readlines("#{Origen.root}/doc/history").each do |line|
        if line =~ /^#+ by (.*) on /
          c << Regexp.last_match(1)
        end
      end
      c.uniq
    end

    def config
      @config ||= Configuration.new(self)
    end

    def add_config_attribute(*args)
      Application::Configuration.add_attribute(*args)
    end

    # Returns the name of the given application, this is the name that will
    # be used to refer to the application when it is used as a plugin
    def name
      (@name ||= namespace).to_s.underscore.symbolize
    end

    def gem_name
      (Origen.app.config.gem_name || name).to_s.underscore.symbolize
    end

    def plugins
      if Origen.app_loaded?
        @plugins ||= Plugins.new
      else
        Plugins.new
      end
    end

    def plugins_manager
      Origen.deprecated 'Origen.app.plugins_manager and Origen.app.current_plugin are deprecated, use Origen.app.plugins instead'
      plugins
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

    def session(reload = false)
      if current?
        @session = nil if reload
        @session ||= Database::KeyValueStores.new(self, persist: false)
      else
        puts "All plugins should use the top-level application's session store, i.e. use:"
        puts "  Origen.app.session.#{name}"
        puts 'instead of:'
        puts '  Origen.app!.session'
        puts
        exit 1
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

    def pattern_iterators
      @pattern_iterators ||= []
    end

    def callback_listeners
      current = Origen.app.plugins.current
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
      if Origen.top_level
        puts "Attempt to set an instance of #{obj.class} as the top level when there is already an instance of #{Origen.top_level.class} defined as the top-level!"
        fail 'Only one object that include the Origen::TopLevel module can be instantiated per target!'
      end
      $dut = obj
      dynamic_resource(:toplevel_listeners, [], adding: true) << obj
    end

    # Any attempts to instantiate a tester within the give block will be forced to instantiate
    # an Origen::Tester::Doc instance
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
      $tester = obj
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

    def load_target!(options = {})
      options = {
        force_debug: false
      }.merge(options)
      @on_create_called = false
      @target_loading = true
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
      # declares here, the objects registered with origen should be refreshed accordingly
      clear_dynamic_resources
      load_event(:transient) do
        Origen.mode = Origen.app.session.origen_core[:mode] || :production # Important since a production target may rely on the default
        begin
          $_target_options = @target_load_options
          Origen.target.set_signature(@target_load_options)
          $dut = nil
          load environment.file if environment.file
          if target.proc
            target.proc.call
          else
            load target.file!
          end
        ensure
          $_target_options = nil
        end
        @target_instantiated = true
        Origen.mode = :debug if options[:force_debug]
        listeners_for(:on_create).each do |obj|
          unless obj.is_a?(Origen::SubBlocks::Placeholder)
            if obj.try(:is_a_model_and_controller?)
              m = obj.model
              c = obj.controller
              m.on_create if m.respond_to_directly?(:on_create)
              c.on_create if c.respond_to_directly?(:on_create)
            else
              obj.on_create
            end
          end
        end
        @on_create_called = true
        # Keep this within the load_event to ensure any objects that are further instantiated objects
        # will be associated with (and cleared out upon reload of) the current target
        listeners_for(:on_load_target).each(&:on_load_target)
      end
      listeners_for(:after_load_target).each(&:after_load_target)
      Origen.app.plugins.validate_production_status
      @target_loading = false
    end

    # Returns true if the on_create callback has already been called during a target load
    def on_create_called?
      !!@on_create_called
    end

    # Not a clean unload, but allows objects to be re-instantiated for testing
    # @api private
    def unload_target!
      listeners_for(:before_load_target).each(&:before_load_target)
      clear_dynamic_resources
      clear_dynamic_resources(:static)
      Origen::Pins.clear_pin_aliases
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
      @top_level = nil
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

    def target_loading?
      @target_loading || false
    end

    # Prepends the application name to the fail message and throws a RuntimeError exception.
    # Very similar to the plain <code>fail</code> method with the addition of prepending the application name.
    # Prepended message: 'Fail in app.name: '
    # If no message if provided, message is set to 'Fail in app.name'
    # @param message [String] Message to print with the exception. If the message option is nil, a default message will be used instead.
    # @param exception_class [Class] Custom Exception class to throw. May require the full namespace, e.g. <code>Origen::OrigenError</code> instead of just <code>OrigenError</code>.
    # @raise [RuntimeError, exception_class] Option exception_class is raised, defaulting to <code>RuntimeError</code>.
    def fail(message: nil, exception_class: RuntimeError)
      message.nil? ? message = "Fail in #{name}" : message = "Fail in #{name}: #{message}"
      e = exception_class.new(message)

      # If the caller is Origen.app.fail!, remove this caller from the backtrace, leaving where Origen.app.fail! was called.
      # As an aside, if there's an exception raised in Origen.app.fail!, then that would actually raise a Kernel.fail, so there's no concern with masking
      # out a problem with Origen.app.fail! by doing this.
      if caller[0] =~ (/lib\/origen\/application.rb:\d+:in `fail!'/)
        e.set_backtrace(caller[1..-1])
      else
        e.set_backtrace(caller)
      end
      Kernel.fail(e)
    end

    # Similar to Origen.app.fail, but will instead print the message using Origen.log.error and exit the current process (using <code>exit 1</code>)
    # UNLESS --debug is used. In those cases, <code>exit</code> will not be used and instead this will behave the same as {Origen::Application#fail}.
    # Purpose here is to allow fail! for normal usage, but provide more details as to where fail! was used when running in debug.
    # @param message [String] Message to print with the exception. If the message option is nil, a default message will be used instead.
    # @param exception_class [Class] Custom Exception class to throw. May require the full namespace.
    # @param exit_status [Integer] Exit status to use when exiting the application.
    # @raise [RuntimeError, SystemExit, exception_class] When debug is disabled, <code>SystemExit</code> will be raised.
    #   When debug is enabled, exception_class will be raised, defaulting to <code>RuntimeError</code>.
    def fail!(message: nil, exception_class: RuntimeError, exit_status: 1)
      if Origen.debug?
        # rubocop:disable Style/RedundantSelf
        self.fail(message: message, exception_class: exception_class)
        # rubocop:enable Style/RedundantSelf
      else
        begin
          # rubocop:disable Style/RedundantSelf
          self.fail(message: message, exception_class: exception_class)
          # rubocop:enable Style/RedundantSelf
        rescue exception_class => e
          Origen.log.error(e.message)
          exit exit_status
        end
      end
    end

    # This method is called just after an application inherits from Origen::Application,
    # allowing the developer to load classes in lib and use them during application
    # configuration.
    #
    #   class MyApplication < Origen::Application
    #     require "my_backend" # in lib/my_backend
    #     config.i18n.backend = MyBackend
    #   end
    def add_lib_to_load_path! #:nodoc:
      [root.join('lib'), root.join('vendor', 'lib'), root.join('app', 'lib')].each do |path|
        $LOAD_PATH.unshift(path.to_s) if File.exist?(path) && !$LOAD_PATH.include?(path.to_s)
      end
    end
  end
end
