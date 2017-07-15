module Origen
  module Database
    class KeyValueStore
      attr_reader :name
      # Returns the parent database (the application's collection of
      # key-value stores)
      attr_reader :database
      attr_accessor :private

      def initialize(database, name)
        @name = name
        @database = database
        @private = false
      end

      # Read a value from the store
      def [](key)
        refresh if stale?
        store[key]
      end

      # Persist a new value to the store
      def []=(key, val)
        refresh if persisted?
        store[key] = val
        save_to_file
        val
      end

      # Force a refresh of the database
      def refresh
        unless @uncommitted || !persisted?
          dssc.check_out(file, version: 'Trunk', force: true)
          record_refresh
        end
      end

      def record_refresh
        database.record_refresh(name)
        @store = nil
      end

      # Returns true if the database is due a time-based refresh, note that
      # this has no bearing on whether or not someone else has committed to
      # the store since the last refresh
      def stale?
        if persisted?
          t = database.time_since_refresh(name)
          !t || store[:refresh_interval_in_minutes] == 0 || t > store[:refresh_interval_in_minutes]
        else
          false
        end
      end

      def persisted?
        database.persisted?
      end

      def private?
        @private
      end

      # Check if the store has a key
      def has_key?(key)
        store.include? key
      end

      # Remove the session file in the case it gets corrupted
      # This can happen when a complex object is not handled
      # correctly by the Marshal method.
      def rm_session_file
        FileUtils.rm_f(file)
      end

      # Deletes a key from the active store
      def delete_key(key)
        store.delete(key)
      end
      
      # Return an array of store keys
      def keys
        store.keys
      end
      
      def user_keys
        store.keys.reject { |k| k.to_s.match(/refresh_interval_in_minutes/) }
      end
      
      private

      def dssc
        @dssc ||= Origen::Utility::DesignSync.new
      end

      def store
        @store ||= begin
          if file.exist?
            load_from_file
          elsif persisted? && dssc.managed_by_design_sync?(file)
            refresh
            load_from_file
          else
            @uncommitted = true
            { refresh_interval_in_minutes: 60 }
          end
        end
      end

      def load_from_file
        s = nil
        File.open(file.to_s) do |f|
          s = Marshal.load(f)
        end
        s
      end

      def save_to_file
        unless file.dirname.exist?
          FileUtils.mkdir_p(file.dirname.to_s)
        end
        if @uncommitted
          database.record_new_store(name)
          @uncommitted = false
        end
        File.open(file.to_s, 'w') do |f|
          Marshal.dump(store, f)
        end
        if private?
          FileUtils.chmod(0600, file)
        else
          FileUtils.chmod(0664, file)
        end
        if persisted?
          dssc.check_in file, new: true, keep: true, branch: 'Trunk'
        end
      end

      def file
        file_path = database.app == Origen ? Origen.home : database.app.root
        if persisted?
          @file ||= Pathname.new("#{file_path}/.db/#{name.to_s.symbolize}")
        else
          @file ||= Pathname.new("#{file_path}/.session/#{name.to_s.symbolize}")
        end
      end
    end
  end
end
