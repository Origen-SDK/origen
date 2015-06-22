module Origen
  # Responsible for ensuring that all dependencies defined in
  # config.remotes are available.
  #
  # Workspaces will automatically be created and updated to the
  # correct version as required.
  #
  # An instance of this class is hooked up to:
  #     Origen.remote_manager
  class RemoteManager
    def initialize
      @required = false
    end

    # This will fetch all remotes (if required)
    # It does not add the libs to the load path, and require the environments
    #  since remotes are not assumed to be Ruby.
    def require!
      unless required?
        # Make sure the imports have already been required and added
        # to the load path of the current thread
        unless imports_required?
          fail 'Error: Imports must be required before remotes!'
        end

        while updates_required?
          Origen.log.info 'The following remotes need to be updated, this will now happen automatically:'
          dirty_remotes.each do |name, remote|
            if remote[:path]
              Origen.log.info "  #{name} - #{remote[:path]}"
            else
              Origen.log.info "  #{name} - #{remote[:version]}"
            end
          end
          update!
        end
        @required = true
      end
    end

    # Returns true if the imports have already been required and added
    # to the load path of the current thread
    def required?
      @required
    end

    # Returns true if the imports have already been required and added
    # to the load path of the current thread
    def imports_required?
      Origen.import_manager.required?
    end

    def validate_production_status(force = false)
      if Origen.mode.production? || force
        remotes.each do |_name, remote|
          if remote[:path]
            fail "The following remote is defined as a path, but that is not allowed in production: #{remote}"
          end
          version = Origen::VersionString.new(remote[:version])
          unless version.valid?
            fail "The following remote version is not in a valid format: #{remote}"
          end
          if version.latest?
            fail "Latest is not allowed as a remote version in production: #{remote}"
          end
        end
      end
    end

    # Returns an array of symbols that represent the names of all remotes
    def names
      named_remotes.keys
    end

    # Returns a hash containing all remotes
    def named_remotes
      remotes
    end

    # Returns the path to origen root for the given import name
    def origen_root(name)
      origen_root_for(named_remotes[name])
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

    # Returns true if the given path is a symlink. Since Rubies handling of symlinks is ropey
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

    private

    # Returns the name of the given import (a lower cased symbol)
    def name_of(remote)
      dir_defined?(remote)
      dir = remote[:dir].dup
      dir.gsub! '/', '_'
      name = dir.downcase.to_sym
    end

    # Returns the name of the given import (a lower cased symbol)
    def dir_of(remote)
      dir_defined?(remote)
      dir = remote[:dir]
    end

    def dir_defined?(remote)
      if remote[:dir].nil?
        Origen.log.error 'A problem was encountered with a configuration remote'
        Origen.log.error "Error: ':dir' must be defined for each remote."
        fail 'Remote error!'
      end
      true
    end

    def origen_root_for(remote, options = {})
      workspace = Pathname.new(workspace_of(remote))
      if File.exist?("#{workspace}/config/application.rb")
        root = workspace
      elsif remote[:app_path] && File.exist?("#{workspace}/#{remote[:app_path]}/config/application.rb")
        root = workspace.join(remote[:app_path])
      else
        root = workspace.join('tool_data', 'origen')
      end
      if File.exist?("#{root}/config/application.rb")
        root
      else
        if options[:accept_missing]
          nil
        else
          Origen.log.error 'A problem was encountered with the following remote:'
          Origen.log.error remote
          Origen.log.error 'Please check that all vault, version or path references are correct.'
          Origen.log.error ''
          Origen.log.error 'If you are sure that the remote is setup correctly and this error'
          Origen.log.error 'persists, you can try running the following command to blow away'
          Origen.log.error 'the local remote cache and then try again from scratch:'
          Origen.log.error ''
          Origen.log.error "rm -fr #{ws.remotes_directory}"
          Origen.log.error ''
          fail 'Remote error!'
        end
      end
    end

    def updates_required?
      resolve_remotes
      dirty_remotes.size > 0
    end

    def dirty_remotes
      remotes.select do |_name, remote|
        dirty?(remote)
      end
    end

    def dirty?(remote)
      if remote[:path] && path_enabled?(remote)
        false
      else
        (!remote[:path] && path_enabled?(remote)) ||
          (remote[:path] && !path_enabled?(remote)) ||
          current_version_of(remote) != remote[:version]
      end
    end

    def current_version_of(remote)
      ws.current_version_of(workspace_of(remote))
    end

    # Returns true if the given import is currently setup as a path
    def path_enabled?(remote)
      dir = workspace_of(remote)
      File.exist?(dir) && symlink?(dir)
    end

    # Populate an array of required remotes from the current application
    # state and resolve any duplications or conflicts.
    # Conflicts are resolved by the following rules:
    #   * A path reference always wins.
    #   * If two different paths are found an errors will be raised.
    #   * If multiple versions of the same remote are found the most
    #     recent one wins.
    def resolve_remotes
      @remotes = {}
      top_level_remotes
      top_level_remotes.each do |remote|
        traverse_remotes(remote) do |remote|
          add_remote(remote)
        end
      end
      # Add remotes from imports
      Origen.plugins.each do |plugin|
        plugin.config.remotes.each do |import_remote|
          add_remote(import_remote)
        end
      end
      @remotes
    end

    def top_level_remotes
      Origen.app.config.remotes    #+ Origen.app.config.remotes_dev (there are no core remotes at this time)
    end

    # Walks down an import tree recursively yielding all nested imports, if
    # the imported application has not been populated yet then it will
    # not return any nested imports.
    #
    # This will also update the required origen version if a app
    # instance is encountered that requires a newer version than the current
    # version.
    def traverse_remotes(remote, &block)
      yield remote
      if remote_present?(remote)
        app = Origen.application_instance(origen_root_for(remote), reload: true)
        app.config.remotes.each do |remote|
          traverse_remotes(remote, &block)
        end
      end
    end

    def remotes
      @remotes ||= resolve_remotes
    end

    def remote_present?(remote)
      !!origen_root_for(remote, accept_missing: true)
    end

    # Conflicts are resolved by the following rules:
    #   * A path reference always wins.
    #   * If two different paths are found an errors will be raised.
    #   * If multiple versions of the same remote are found the most
    #     recent one wins.
    def add_remote(new)
      name = name_of(new)
      # If the current remote has been imported by one of it's dev dependencies
      # then always use the local workspace
      if name == @current_app_name
        new = @current_app
      end
      existing = remotes[name]
      if existing
        if new[:path]
          if existing[:path]
            if existing[:path] != new[:path]
              Origen.log.error 'Cannot resolve remote dependencies due to conflicting paths:'
              Origen.log.error "  #{name}:"
              Origen.log.error "    - #{existing[:path]}"
              Origen.log.error "    - #{new[:path]}"
              Origen.log.error ''
              fail 'Remote error!'
            end
          else
            remotes[name] = new
          end
        elsif existing[:version] != new[:version]
          existing_version = Origen::VersionString.new(existing[:version])
          if existing_version.less_than?(new[:version])
            remotes[name] = new
          end
        end
      else
        remotes[name] = new
      end
    end

    # Makes all dirty imports clean
    def update!
      ensure_remotes_directory
      dirty_remotes.each do |_name, remote|
        dir = workspace_of(remote)
        if remote[:path] || path_enabled?(remote)
          if symlink?(dir)
            delete_symlink(dir)
          else
            FileUtils.rm_rf(dir) if File.exist?(dir)
          end
        end
        if remote[:path]
          create_symlink(remote[:path], dir)

        else
          unless File.exist?("#{dir}/.initial_populate_successful")
            ws.build(dir, rc_url: remote[:vault], allow_rebuild: true)
            ws.switch_version(dir, remote[:version])
            `touch "#{dir}/.initial_populate_successful"`
          end
          ws.switch_version(dir, remote[:version])
        end
      end
    end

    def workspace_of(remote)
      Pathname.new("#{ws.remotes_directory}/#{dir_of(remote)}")
    end

    def ensure_remotes_directory
      unless remotes.empty?
        unless File.exist?(ws.remotes_directory)
          FileUtils.mkdir_p(ws.remotes_directory)
        end
      end
    end

    def ws
      Origen.app.workspace_manager
    end
  end
end
