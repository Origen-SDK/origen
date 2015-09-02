module Origen
  class Application
    # This module is deprecated and is replaced by Origen::Application::Plugins
    class PluginsManager
      # ***********************************************************************
      # ***********************************************************************
      # Don't add anything new here, use origen/application/plugins.rb instead
      # ***********************************************************************
      # ***********************************************************************

      # Returns the current plugin name, equivalent to calling current.name
      def name
        Origen.deprecated 'Origen.current_plugin.name is deprecated, use Origen.app.plugins.name instead'
        if Origen.app.plugins.current
          Origen.app.plugins.current.name
        end
      end

      # Sets the given plugin as the temporary current plugin, this will last until
      # changed or the end of the current Origen thread
      def temporary=(plugin_name)
        Origen.deprecated 'Origen.current_plugin.temporary= is deprecated, use Origen.app.plugins.temporary= instead'
        Origen.app.plugins.temporary = plugin_name
      end

      # Same as temporary= except it will be remembered in the next Origen thread.
      # Setting this will also clear any temporary assignment that is currently in
      # effect.
      def default=(plugin_name)
        Origen.deprecated 'Origen.current_plugin.default= is deprecated, use Origen.app.plugins.current= instead'
        Origen.app.plugins.current = plugin_name
      end

      # Returns the current plugin instance currently set as the default plugin,
      # otherwise nil
      def default
        Origen.deprecated 'Origen.current_plugin.default is deprecated, use Origen.app.plugins.current instead'
        Origen.app.plugins.current
      end
    end
  end
end
