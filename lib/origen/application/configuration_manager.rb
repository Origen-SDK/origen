module Origen
  class Application
    # All access to the configuration management system should be done
    # through methods of this class, an instance of which is accessible via
    # Origen.app.cm
    #
    # Where possible external arguments relating to the underlying CM tool should
    # not be used, try and keep method names and arguments generic.
    #
    # Right now it supports Design Sync only, but by eliminating interaction
    # with DS outside of this class it means that a future change to the CM
    # system should be easily handled by simply swapping in a new ConfigurationManager
    # class.
    class ConfigurationManager
      def initialize
        @cm = Origen::Utility::DesignSync.new
      end

      def modified_objects_in_workspace?
        @cm.modified_objects?(workspace_dirs, rec: true, fullpath: true)
      end

      def modified_objects_in_workspace_list
        @cm.modified_objects(workspace_dirs, rec: true, fullpath: true)
      end

      def unmanaged_objects_in_workspace?
        @cm.modified_objects?(workspace_dirs, rec: true, unmanaged: true, managed: false, fullpath: true)
      end

      def unmanaged_objects_in_workspace_list
        @cm.modified_objects(workspace_dirs, rec: true, unmanaged: true, managed: false, fullpath: true)
      end

      def modified_objects_in_repository?
        @cm.modified_objects?(workspace_dirs, rec: true, fullpath: true, remote: true)
      end

      def modified_objects_in_repository_list
        @cm.modified_objects(workspace_dirs, rec: true, fullpath: true, remote: true)
      end

      def workspace_dirs
        "#{Origen.root} " + Origen.app.config.external_app_dirs.join(' ')
      end

      # Fetch the latest version of the application
      def fetch_latest(options = {})
        options = {
          force: false
        }.merge(options)
        @cm.populate(workspace_dirs, rec: true, verbose: true, force: options[:force])
      end

      def diff_cmd(options = {})
        @cm.diff_cmd(options)
      end

      def import(*args)
        @cm.import(*args)
      end

      def ensure_workspace_unmodified!
        if modified_objects_in_workspace?
          puts <<-EOT
Your workspace has local modifications that are preventing the requested action
  - run 'origen rc mods' to see them.
          EOT
          exit 1
        end
      end

      def method_missing(method, *args, &blk)
        @cm.send(method, *args, &blk)
      end
    end
  end
end
