module Origen
  # Responsible for ensuring that all dependencies defined in
  # config.imports are available.
  #
  # Workspaces will automatically be created and updated to the
  # correct version as required.
  #
  # An instance of this class is hooked up to:
  #     Origen.import_manager
  class ImportManager
    SHARED_CONTENTS_TYPES = [:pattern, :templates, :command_launcher, :program]

    def initialize
      @required = false
    end

    # This will fetch all imports (if required), add the libs to
    # the load path, and require the environments.
    def require!
    end

    # Returns true if the imports have already been required and added
    # to the load path of the current thread
    def required?
      @required
    end

    def required=(value)
      @required = value
    end

    def validate_production_status(force = false)
      if Origen.mode.production? || force
        if File.exist?("#{Origen.root}/Gemfile")
          File.readlines("#{Origen.root}/Gemfile").each do |line|
            # http://rubular.com/r/yNGDGB6M2r
            if line =~ /^\s*gem\s+(("|')\w+("|')),.*(:path\s*=>|path:)/
              fail "The following gem is defined as a path in your Gemfile, but that is not allowed in production: #{Regexp.last_match[1]}"
            end
          end
        end
      end
    end

    # Returns the version of the given plugin that is installed
    def plugin_version(plugin_name)
      load File.join(origen_root_for(imports[plugin_name]), 'config', 'version.rb')
      Origen::VersionString.new(Origen.import_manager.plugin_instance(plugin_name).class::VERSION)
    end

    # Returns the app instance of the given plugin name
    def plugin_instance(name)
      Origen.application_instance(origen_root_for(imports[name]))
    end

    # Returns an array of symbols that represent the names of all imports
    def names
      return @names if @names
      names = Origen.plugins.map(&:name)
      # Had a bug where this was caching too early, don't cache until all plugins are loaded
      @names = names if Origen.app_loaded?
      names
    end

    # Returns a hash containing all imports
    def named_imports
      imports
    end

    # Returns the path to origen root for the given import name
    def origen_root(name)
      origen_root_for(named_imports[name])
    end

    # Handles all symlink creation since Ruby/Windows is ropey. On windows it will create
    # an additional flag file to easily tell us a symlink is active later.
    # @api private
    def create_symlink(from, to)
      if Origen.running_on_windows?
        system("call mklink /D #{to.to_s.gsub('/', '\\')} #{from.to_s.gsub('/', '\\')}")
        File.new("#{to}_is_a_symlink", 'w') {}
      else
        FileUtils.symlink from, to
      end
    end

    # Manually handle symlink deletion to support windows
    # @api private
    def delete_symlink(path)
      if Origen.running_on_windows?
        # Don't use regular rm on windows symlink, will delete into the remote dir!
        system("call cmd /c rmdir #{path.to_s.gsub('/', '\\')}")
        FileUtils.rm_f("#{path}_is_a_symlink")
      else
        FileUtils.rm_f(path)
      end
    end

    # Returns true if the given path is a symlink. Since Ruby's handling of symlinks is ropey
    # we will manually maintain a flag (an empty file that means true when present) to indicate
    # when an import is currently setup as a symlink to a path.
    # @api private
    def symlink?(path)
      if Origen.running_on_windows?
        File.exist?("#{path}_is_a_symlink")
      else
        File.symlink?(path)
      end
    end

    # Returns true if the given file is a symlink and a link to a file
    # within the application's imports directory, generally this can be used
    # to identify symlinks which have been added by the imports/plugin manager
    # to expose the pattern/program/templates directories of plugins
    def symlink_to_imports_dir?(path)
      if Origen.running_on_windows?
        # Not sure how to do this yet on windows, for now just defaulting
        # to the original behavior of testing if it is a symlink
        symlink?(path)
      else
        if File.symlink?(path)
          !!(File.readlink(path) =~ /^#{ws.imports_directory}/)
        end
      end
    end

    # Return the plugin name if the path specified is
    # from that plugin
    def path_within_a_plugin(path)
      ret_value = nil
      names.each do |plugin|
        subpath = path.slice(/.*\/#{plugin.to_s}/)
        if subpath && symlink?(subpath)
          ret_value = (plugin.to_sym if plugin.class != Symbol) || plugin
          break
        end
      end
      ret_value
    end

    # Returns a list of paths which are symlinks within the supplied dir
    def symlinks_in_dir(dir)
      list = []
      if File.exist?(dir)
        Dir.entries(dir).each do |file|
          if symlink_to_imports_dir?("#{dir}/#{file}")
            list << "#{dir}/#{file}"
          end
        end
      end
      list
    end

    # Returns all symlinks created by adding plugins
    # Usage right now is to mask these links in unmanaged files.
    def all_symlinks
      links = []
      SHARED_CONTENTS_TYPES.each do |type|
        links << symlinks_in_dir("#{type}") unless type == :command_launcher
      end
      links.flatten.uniq.compact
    end

    # Deletes any symlink pointing to the shared content of the
    # specified plugin
    def delete_symlinks_of_plugin(plugin)
      SHARED_CONTENTS_TYPES.each do |type|
        unless type == :command_launcher
          link = "#{Origen.root}/#{type}/#{plugin.name}"
          if File.exist?(link)
            delete_symlink(link) if symlink?(link)
          end
        end
      end
    end

    def command_launcher
      @command_launcher ||= []
    end

    private

    # Returns the name of the given import (a lower cased symbol)
    def name_of(import)
      vault = import[:vault].dup
      vault.gsub!(/(\/|\\)tool_data(\/|\\)origen.*$/, '')
      if import[:app_path]
        path = import[:app_path]
        path = "/#{path}" unless path[0] == '/'
        vault.gsub! path, ''
      end
      name = vault.split('/').last.downcase.to_sym
    end

    def require_environments!
      resolve_imports
      ordered_imports.reverse_each do |name|
        root = origen_root_for(imports[name.to_sym])
        Origen.with_origen_root(root) do
          require root.join('config', 'environment')
        end
      end
    end

    def add_libs_to_load_path!
      imports.each do |_name, import|
        root = origen_root_for(import)
        [root.join('lib'), root.join('vendor', 'lib')].each do |path|
          $LOAD_PATH.unshift(path.to_s) if File.exist?(path) && !$LOAD_PATH.include?(path.to_s)
        end
      end
    end

    # Reads config.shared from the given plugin and returns the types of contents
    # that are shared.
    def shared_types(plugin_name)
      types = []
      shared = plugin_instance(plugin_name).config.shared
      if shared
        shared.each do |type, _data|
          types << check_type(type) if check_type(type)
        end
      end
      types
    end

    # Checks whether the shared content type is valid or not
    def check_type(type)
      type = :pattern if type == :patterns
      type = :program if type == :programs
      type = :templates if type == :template
      if SHARED_CONTENTS_TYPES.include?(type)
        return type
      end
    end

    def remove_unwanted_symlinks!
      SHARED_CONTENTS_TYPES.each do |type|
        symlinks = symlinks_in_dir("#{Origen.root}/#{type}") unless type == :command_launcher
        if symlinks
          symlinks.each do |symlink|
            plugin = path_within_a_plugin(symlink)
            unless plugin && shared_types(plugin) && shared_types(plugin).include?(type)
              delete_symlink(symlink)
            end
          end
        end
      end
    end

    # Removes symlinks of all plugins, irrespective of whether it is active or not.
    def remove_all_symlinks!
      remove_unwanted_symlinks!
      Origen.plugins.each do |plugin|
        delete_symlinks_of_plugin(plugin)
      end
    end

    # Adds symlinks of shared contents from imported plugins and includes shared commands
    def add_shared_contents!
      [Origen.app, Origen.plugins].flatten.each do |plugin|
        shared_content = plugin.config.shared
        if shared_content
          shared_content.each do |type, data|
            type = check_type(type)
            if type && type != :command_launcher
              # Disabling symlinks, too hard to manage and a direct root into the gem bundle seems
              # too dangerous
              # if File.exist?("#{plugin.root}/#{data}")
              #  FileUtils.mkdir_p("#{Origen.root}/#{type}") unless File.exist?("#{Origen.root}/#{type}")
              #  unless File.exist?("#{Origen.root}/#{type}/#{plugin.name}/")
              #    create_symlink("#{plugin.root}/#{data}", "#{Origen.root}/#{type}/#{plugin.name}")
              #  end
              # else
              #  fail "Invalid path to #{type} dir in shared content of plugin #{plugin.name}!"
              # end
            elsif type == :command_launcher
              command_launcher << "#{plugin.root}/#{data}"
            else
              # ignore anything else
              if Origen.config.strict_errors
                puts "Unrecognized shared content type #{type} of plugin #{plugin.name}"
                fail 'Invalid shared parameter!'
              end
            end
          end
        end
      end
    end

    def origen_root_for(import, options = {})
      workspace = Pathname.new(workspace_of(import))
      if File.exist?("#{workspace}/config/application.rb")
        root = workspace
      elsif import[:app_path] && File.exist?("#{workspace}/#{import[:app_path]}/config/application.rb")
        root = workspace.join(import[:app_path])
      else
        root = workspace.join('tool_data', 'origen')
      end
      if File.exist?("#{root}/config/application.rb")
        root
      else
        if options[:accept_missing]
          nil
        else
          puts 'A problem was encountered with the following import:'
          puts import
          puts 'Please check that all vault, version or path references are correct.'
          puts ''
          puts 'If you are sure that the import is setup correctly and this error'
          puts 'persists, you can try running the following command to blow away'
          puts 'the local import cache and then try again from scratch:'
          puts ''
          puts "rm -fr #{ws.imports_directory}"
          puts ''
          fail 'Import error!'
        end
      end
    end

    def updates_required?
      @current_app_name = Origen.app.name
      @current_app = {
        vault: Origen.app.config.vault,
        path:  Origen.root
      }
      resolve_imports
      dirty_imports.size > 0
    end

    def dirty_imports
      imports.select do |_name, import|
        dirty?(import)
      end
    end

    def dirty?(import)
      if import[:path] && path_enabled?(import)
        false
      else
        (!import[:path] && path_enabled?(import)) ||
          (import[:path] && !path_enabled?(import)) ||
          current_version_of(import) != import[:version]
      end
    end

    def current_version_of(import)
      ws.current_version_of(workspace_of(import))
    end

    # Returns true if the given import is currently setup as a path
    def path_enabled?(import)
      dir = workspace_of(import)
      File.exist?(dir) && symlink?(dir)
    end

    # Populate an array of required imports from the current application
    # state and resolve any duplications or conflicts.
    # Conflicts are resolved by the following rules:
    #   * A path reference always wins.
    #   * If two different paths are found an errors will be raised.
    #   * If multiple versions of the same plugin are found the most
    #     recent one wins.
    def resolve_imports
      @imports = {}
      @ordered_imports = []
      top_level_imports
      top_level_imports.each do |import|
        traverse_imports(import) do |import|
          add_import(import)
        end
      end
      @imports
    end

    def top_level_imports
      Origen.app.config.imports + Origen.app.config.imports_dev
    end

    # Walks down an import tree recursively yielding all nested imports, if
    # the imported application has not been populated yet then it will
    # not return any nested imports.
    #
    # This will also update the required origen version if a app
    # instance is encountered that requires a newer version than the current
    # version.
    def traverse_imports(import, &block)
      yield import
      if import_present?(import)
        app = Origen.application_instance(origen_root_for(import), reload: true)
        update_required_origen_version(app)
        app.config.imports.each do |import|
          traverse_imports(import, &block)
        end
      end
    end

    # If the given app (plugin) requires a newer Origen than the current latest
    # required version then the required version parameter will be updated.
    def update_required_origen_version(app)
      min = app.config.required_origen_version || app.config.min_required_origen_version
      max = app.config.max_required_origen_version
      if min
        if @required_origen_version
          latest = Origen::VersionString.new(@required_origen_version)
          if latest.less_than?(min)
            @required_origen_version = min
          end
        else
          @required_origen_version = min
        end
      end
      if max
        if @max_required_origen_version
          latest = Origen::VersionString.new(@max_required_origen_version)
          if latest.less_than?(max)
            @max_required_origen_version = max
            @max_lib = app.class.to_s.sub('_Application', '')
          end
        else
          @max_required_origen_version = max
          @max_lib = app.class.to_s.sub('_Application', '')
        end
      end
    end

    def imports
      @imports ||= resolve_imports
    end

    def ordered_imports
      @ordered_imports
    end

    def import_present?(import)
      !!origen_root_for(import, accept_missing: true)
    end

    # Conflicts are resolved by the following rules:
    #   * A path reference always wins.
    #   * If two different paths are found an errors will be raised.
    #   * If multiple versions of the same plugin are found the most
    #     recent one wins.
    def add_import(new)
      name = name_of(new)
      # If the current app has been imported by one of it's dev dependencies
      # then always use the local workspace
      if name == @current_app_name
        new = @current_app
      end
      existing = imports[name]
      if existing
        if new[:path]
          if existing[:path]
            if existing[:path] != new[:path]
              puts 'Cannot resolve plugin dependencies due to conflicting paths:'
              puts "  #{name}:"
              puts "    - #{existing[:path]}"
              puts "    - #{new[:path]}"
              puts ''
              fail 'Import error!'
            end
          else
            ordered_imports.delete(name.to_s)
            ordered_imports.push(name.to_s)
            imports[name] = new
          end
        elsif existing[:version] != new[:version]
          existing_version = Origen::VersionString.new(existing[:version])
          if existing_version.less_than?(new[:version])
            ordered_imports.delete(name.to_s)
            ordered_imports.push(name.to_s)
            imports[name] = new
          end
        else
          ordered_imports.delete(name.to_s)
          ordered_imports.push(name.to_s)
        end
      else
        ordered_imports.push(name.to_s)
        imports[name] = new
      end
    end

    # Makes all dirty imports clean
    def update!
      ensure_imports_directory
      dirty_imports.each do |_name, import|
        dir = workspace_of(import)
        if import[:path] || path_enabled?(import)
          if symlink?(dir)
            delete_symlink(dir)
          else
            FileUtils.rm_rf(dir) if File.exist?(dir)
          end
        end
        if import[:path]
          create_symlink(import[:path], dir)

        else
          unless File.exist?("#{dir}/.initial_populate_successful")
            ws.build(dir, vault: import[:vault], allow_rebuild: true)
            ws.switch_version(dir, import[:version])
            `touch "#{dir}/.initial_populate_successful"`
          end
          ws.switch_version(dir, import[:version])
        end
      end
    end

    def workspace_of(import)
      Pathname.new("#{ws.imports_directory}/#{name_of(import)}")
    end

    def ensure_imports_directory
      unless imports.empty?
        unless File.exist?(ws.imports_directory)
          FileUtils.mkdir_p(ws.imports_directory)
        end
      end
    end

    def ws
      Origen.app.workspace_manager
    end
  end
end
