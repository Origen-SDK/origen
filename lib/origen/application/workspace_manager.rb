module Origen
  class Application
    class WorkspaceManager
      # Returns the directory that contains the current application's revision control
      # root (basically just Origen.app.rc.root.parent)
      def container_directory
        if Origen.running_on_windows?
          dir = revision_control_root.parent
          Pathname.new(dir.to_s.sub(/\/$/, ''))
        else
          revision_control_root.parent
        end
      end

      # Returns the path to the root directory of the revision control system
      # that is managing the application.
      #
      # This may not necessarily be Origen.root if the application is embedded within
      # a larger project workspace (for example in tool_data/origen)
      def revision_control_root
        Origen.app.rc ? Origen.app.rc.root : Origen.root
      end

      # Origen.root may not necessarily be the same as the revision control root.
      # This method will return the relative path from the revision control root to
      # Origen.root.
      def path_to_origen_root
        path = Origen.root.to_s.sub(revision_control_root.to_s, '').sub(/^(\/|\\)/, '')
        path = '.' if path.empty?
        path
      end

      # Provides a proposal for where the reference workspace should live
      def reference_workspace_proposal
        "#{container_directory}/#{Origen.app.name}_reference"
      end

      # Returns the path to the actual reference workspace if it is set,
      # otherwise returns nil
      def reference_workspace
        if reference_workspace_set?
          dir = File.readlink(reference_dir)
          dir.gsub!('.ref', '')
          dir.gsub!(/#{Regexp.escape(path_to_origen_root)}\/?$/, '')
          Pathname.new(dir).cleanpath
        end
      end

      # Returns the path to the directory that will be used to contain
      # all imported application workspaces
      def imports_directory
        return @imports_directory if @imports_directory
        old = "#{container_directory}/#{revision_control_root.basename}_imports_DO_NOT_HAND_MODIFY"
        @imports_directory = "#{container_directory}/.#{revision_control_root.basename}_imports_DO_NOT_HAND_MODIFY"
        FileUtils.rm_rf(old) if File.exist?(old)
        @imports_directory
      end

      # Returns the path to the directory that will be used to contain
      # all remotes workspaces
      def remotes_directory
        return @remotes_directory if @remotes_directory
        old = "#{container_directory}/#{revision_control_root.basename}_remotes_DO_NOT_HAND_MODIFY"
        @remotes_directory = "#{container_directory}/.#{revision_control_root.basename}_remotes_DO_NOT_HAND_MODIFY"
        FileUtils.rm_rf(old) if File.exist?(old)
        @remotes_directory
      end

      # Returns true if the local reference directory is already
      # pointing to an external workspace.
      def reference_workspace_set?
        f = reference_dir
        File.exist?(f) && File.symlink?(f) &&
          File.exist?(File.readlink(f))
      end

      def set_reference_workspace(workspace)
        f = reference_dir
        if File.exist?(f)
          if File.symlink?(f)
            FileUtils.rm_f(f)
          else
            FileUtils.rm_rf(f)
          end
        end
        remote_ref = "#{origen_root(workspace)}/.ref"
        unless File.exist?(remote_ref)
          FileUtils.mkdir_p(remote_ref)
          `touch #{remote_ref}/dont_delete`  # Make sure the pop does not blow this away
        end
        if Origen.running_on_windows?
          system("call mklink /h #{reference_dir} #{remote_ref}")
        else
          File.symlink(remote_ref, reference_dir)
        end
      end

      # Returns the full path to Origen.root within the given workspace
      def origen_root(workspace)
        Pathname.new("#{workspace}/#{path_to_origen_root}").cleanpath
      end

      def reference_dir
        "#{Origen.root}/.ref" # Should probably be set by a config parameter
      end

      # Builds a new workspace at the given path
      def build(path, options = {})
        options = {
          rc_url:        Origen.app.config.rc_url || Origen.app.config.vault,
          allow_rebuild: false
        }.merge(options)
        if File.exist?(path.to_s) && !options[:allow_rebuild]
          fail "Sorry but #{path} already exists!"
        end
        FileUtils.rm_rf(path.to_s) if File.exist?(path.to_s)
        rc = RevisionControl.new options.merge(remote: options[:rc_url], local: path.to_s)
        rc.build
      end

      # Switches the given workspace path to the given version tag
      def switch_version(workspace, tag, options = {})
        options = {
          origen_root_only: false, # When true pop the Origen.root dir only instead
          # of the whole application workspace - these may or may
          # not be the same thing depending on the application.
        }.merge(options)
        version_file = "#{workspace}/.current_version"
        FileUtils.rm_f(version_file) if File.exist?(version_file)
        if options[:origen_root_only]
          dir = "#{workspace}/#{path_to_origen_root}"
        else
          dir = workspace
        end
        rc_url = Origen.app.config.rc_url || Origen.app.config.vault
        rc = RevisionControl.new remote: rc_url, local: dir.to_s
        rc.checkout version: tag, force: true
        File.open(version_file, 'w') do |f|
          f.puts tag
        end
      end

      def current_version_of(workspace)
        f = "#{workspace}/.current_version"
        if File.exist?(f)
          File.readlines(f).first.strip
        end
      end
    end
  end
end
