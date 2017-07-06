module Origen
  module Database
    class KeyValueStores
      # Returns the application that owns the database
      attr_reader :app

      def initialize(app, options = {})
        options = {
          persist: true
        }.merge(options)
        @app = app
        @persist = options[:persist]
      end

      def inspect
        if persisted?
          app == Origen ? "Origen's Global Database" : "< #{app.class}'s Database >"
        else
          app == Origen ? "Origen's Global Session" : "< #{app.class}'s Session >"
        end
      end

      # Refresh all stores
      def refresh
        if persisted?
          _system.refresh
          files = stores.map { |name| send(name).send(:file) }
          dssc.check_out(files.join(' '), version: 'Trunk', force: true)
          stores.each { |name| send(name).record_refresh }
        end
        nil
      end

      # Returns the time in minutes since the given store
      # was last refreshed
      def time_since_refresh(name)
        if persisted?
          if refresh_table[name]
            ((Time.now - refresh_table[name]) / 60).floor
          end
        else
          Time.now
        end
      end

      # Record that the given store was just refreshed
      def record_refresh(name)
        if persisted?
          t = refresh_table
          t[name] = Time.now
          app.session._database[:refresh_table] = t
        end
      end

      def record_new_store(name)
        unless name == :_system || name == :_database
          _system.refresh
          s = stores
          s << name unless s.include?(name)
          _system[:stores] = s
        end
      end

      # Used to create new key value stores on the fly.
      #
      # On first call of a missing method a method is generated to avoid the missing lookup
      # next time, this should be faster for repeated lookups of the same method, e.g. reg
      def method_missing(method, *args, &block)
        if method.to_s =~ /(=|\(|\)|\.|\[|\]|{|}|\\|\/)/ || [:test, :_system].include?(method)
          fail "Invalid database name: #{method}"
        else
          define_singleton_method(method) do
            loaded[method] ||= KeyValueStore.new(self, method)
          end
        end
        send(method, *args, &block)
      end

      # Returns the names of all known stores
      def stores
        _system[:stores] || []
      end

      def persisted?
        @persist
      end

      def has_key?(key)
        stores.include? key
      end

      private

      def refresh_table
        app.session._database[:refresh_table] ||= {}
      end

      # Persisted key value store used by the database system
      def _system
        @_system ||= KeyValueStore.new(self, :_system)
      end

      def dssc
        @dssc ||= Origen::Utility::DesignSync.new
      end

      def loaded
        @loaded ||= {}
      end
    end
  end
end
