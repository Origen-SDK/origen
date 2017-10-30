module Origen
  class Application
    # Provides an API for working with the application's plugins
    #
    # An instance of this class is instantiated as Origen.app.plugins
    class Plugins < ::Array
      def initialize
        top = Origen.app
        Origen._applications_lookup[:name].each do |_name, app|
          self << app unless app == top
        end
      end

      # Will raise an error if any plugins are currently imported from a path reference
      # in the Gemfile
      def validate_production_status(force = false)
        if Origen.mode.production? || force
          if File.exist?("#{Origen.root}/Gemfile")
            File.readlines("#{Origen.root}/Gemfile").each do |line|
              # http://rubular.com/r/yNGDGB6M2r
              if line =~ /^\s*gem\s+(("|')\w+("|')),.*(:path\s*=>|path:)/
                fail "The following gem is defined as a path in your Gemfile, but that is not allowed in production: #{Regexp.last_match[1]}"
              end
              if line =~ /ORIGEN PLUGIN AUTO-GENERATED/
                fail 'Fetched gems are currently being used in your Gemfile, but that is not allowed in production!'
              end
            end
          end
        end
      end

      # Returns an array of symbols that represent the names of all plugins
      def names
        map(&:name)
      end

      # Returns the current plugin's application instance
      def current
        return nil if @temporary == :none
        return nil if @disabled
        name = @temporary || @current ||= Origen.app.session.origen_core[:default_plugin]
        find { |p| p.name.to_sym == name } if name
      end

      def current=(name)
        name = name.to_sym if name
        Origen.app.session.origen_core[:default_plugin] = name
        if name == :none
          @current = nil
        else
          @current = name
        end
      end

      def temporary=(name)
        name = name.to_sym if name
        @temporary = name
      end

      # Temporarily set the current plugin to nil
      def disable_current
        @disabled = true
        if block_given?
          yield
          @disabled = false
        end
      end

      # Restore the current plugin after an earlier disable
      def enable_current
        @disabled = false
      end

      # @deprecated
      def default=(name)
        Origen.deprecated 'Origen.current_plugin.default= is deprecated, use Origen.app.plugins.current= instead'
        self.current = name
      end

      # @deprecated
      def name
        Origen.deprecated 'Origen.current_plugin.name is deprecated, use Origen.app.plugins.current.name instead'
        current.name if current
      end

      # @deprecated
      def instance
        Origen.deprecated 'Origen.current_plugin.instance is deprecated, use Origen.app.plugins.current instead'
        current
      end

      # @deprecated
      def default
        Origen.deprecated 'Origen.current_plugin.default is deprecated, use Origen.app.plugins.current instead'
        current
      end

      def shared_commands
        [Origen.app, self].flatten.map do |plugin|
          shared = plugin.config.shared || {}
          if shared[:command_launcher]
            "#{plugin.root}/#{shared[:command_launcher]}"
          end
        end.compact
      end

      # Return the plugin name if the path specified is from that plugin
      def plugin_name_from_path(path)
        path = Pathname.new(path).expand_path.cleanpath
        each do |plugin|
          if path.to_s =~ /^#{plugin.root}/
            return plugin.name
          end
        end
        nil
      end
      alias_method :path_within_a_plugin, :plugin_name_from_path
    end
  end
end
