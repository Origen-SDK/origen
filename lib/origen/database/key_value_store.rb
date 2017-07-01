module Origen
  module Database
    class KeyValueStore
      attr_reader :name
      # Returns the parent database (the application's collection of
      # key-value stores)
      attr_reader :database

      def initialize(database, name)
        @name = name
        @database = database
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
      
      # Check if the store has a key
      def has_key?(key)
        store.include? key
      end
      
      def rm_session_file
        FileUtils.rm_f(file)
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
        `chmod u+w #{file}` if file.exist?
        if @uncommitted
          database.record_new_store(name)
          @uncommitted = false
        end
        File.open(file.to_s, 'wb') do |f|
          Marshal.dump(store, f)
        end
        if persisted?
          dssc.check_in file, new: true, keep: true, branch: 'Trunk'
        end
      end

      def file
        if persisted?
          @file ||= Pathname.new("#{database.app.root}/.db/#{name.to_s.symbolize}")
        else
          @file ||= Pathname.new("#{database.app.root}/.session/#{name.to_s.symbolize}")
        end
      end
    end
  end
end
