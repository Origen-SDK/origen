require 'optparse'

options = {}

# App options are options that the application can supply to extend this command
# app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-EOT
Usage:  origen pl
        origen pl [plugin name]
        origen pl [CMD] [plugin name] [options]

Quickstart Examples:
  origen pl                             # Displays the current plugin
  origen pl added                       # Lists the included plugins
  origen pl plugin_name                 # Sets the specified plugin as current plugin
  origen pl reset                       # Resets the current plugin to none
  origen pl describe plugin_name        # Describes the specified plugin
  origen pl add plugin_name va.b.c.dev0 # Adds the plugin of version va.b.c.dev0

The following commands are available:

  list                                Displays all known plugins from the server
  added                               Displays all plugins that are currently included in this app locally
  describe [plugin_name]              Describes the plugin
  add [plugin_name] [version]         Adds the specified plugin if found on server to the local app
  remove [plugin_name]                Removes the specified plugin from this local app
  update [plugin_name] [version]      Updates the specific plugin to the given version

The following options are available:
  EOT
  opts.on('--dev', 'Adds the plugin to config.imports_dev rather that config.imports') { options[:dev_import] = true }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV

if !ARGV[0]
  if Origen.current_plugin.default
    puts "Current plugin is: #{Origen.current_plugin.name}"
  else
    puts <<-EOT
No plugin set!

To work with an included plugin, set it as current plugin using the following command:
    origen pl <plugin-name>
    EOT
  end
else
  case input = ARGV.shift
  when 'reset', 'none'
    Origen.current_plugin.default = :none
    puts 'Successfully cleared the default plugin!'
  when 'add'
    plugin_name = ARGV.shift
    version = ARGV.shift
    if plugin_name && version
      Origen.plugins_manager.add(plugin_name, version, options)
    else
      puts 'Zero or less arguments provided!'
    end
  when 'added'
    Origen.plugins_manager.list_added_plugins
  when 'list'
    Origen.plugins_manager.list
  when 'describe'
    puts Origen.plugins_manager.describe(ARGV.shift)
  when 'remove'
    plugin_name = ARGV.shift
    if plugin_name
      Origen.plugins_manager.remove(plugin_name)
    else
      puts 'No plugin name provided!'
    end
  when 'update'
    plugin_name = ARGV.shift
    version = ARGV.shift
    if plugin_name && version
      Origen.plugins_manager.update(plugin_name, version)
    else
      puts 'Zero or less arguments provided!'
    end

  else

    Origen.current_plugin.default = input.to_sym
    puts "#{Origen.current_plugin.default.name} is now set as the current plugin."
  end

end

# def _workspace_plugin_command
#  puts 'local'
# end
#
# def _global_plugin_command
#  puts 'global'
# end

# if Origen.in_application_directory? || Origen.in_application_subdirectory?
#    _workspace_plugin_command
# else
#    _global_plugin_command
# end
