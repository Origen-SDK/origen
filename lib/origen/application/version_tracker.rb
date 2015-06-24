module Origen
  class Application
    # Keeps track of production released versions
    class VersionTracker
      STORAGE_FILE = "#{Origen.root}/.version_tracker"

      # Returns an array containing all Production release
      # tags since they started being tracked
      def versions
        storage[:versions] ||= []
      end

      # Adds a new version to the tracker
      def add_version(version)
        restore_to_latest
        versions << version
        save
        check_in
      end

      # Returns the persisted storage container (a Hash)
      def storage
        return @storage if @storage
        if File.exist?(STORAGE_FILE)
          File.open(STORAGE_FILE) do |f|
            begin
              @storage = Marshal.load(f)
            rescue
              @storage = {}
            end
          end
        else
          @storage = {}
        end
      end

      # Save the persisted storage container to disk
      def save
        File.open(STORAGE_FILE, 'w') do |f|
          Marshal.dump(storage, f)
        end
      end

      # Check in the persisted storage container
      def check_in
        Origen.app.rc.checkin(STORAGE_FILE, force: true, unmanaged: true, comment: 'Recorded new version in the version tracker')
      end

      # Force the storage container to the latest checked in version
      def restore_to_latest
        @storage = nil
        # Check out the latest version of the storage, forcing to Trunk
        system "dssc co -get -force '#{STORAGE_FILE};Trunk:Latest'"
        system "dssc setselector 'Trunk' #{STORAGE_FILE}"
        `chmod 666 #{STORAGE_FILE}`
      end
    end
  end
end
