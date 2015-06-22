module Origen
  class Application
    class CommandDispatcher
      # Returns true if some pre-built workspace snaphots
      # exist. The location of these is defined by the configuration
      # attribute config.snapshots_directory
      def snapshots_exist?
        File.exist?(Origen.config.snapshots_directory)
      end
    end
  end
end
