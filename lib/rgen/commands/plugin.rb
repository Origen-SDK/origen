require 'optparse'

options = {}

# App options are options that the application can supply to extend this command
# app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-EOT
Usage:  rgen pl
        rgen pl [plugin name]
        rgen pl [CMD] [plugin name] [options]

Quickstart Examples:
  rgen pl                             # Displays the current plugin
  rgen pl added                       # Lists the included plugins
  rgen pl plugin_name                 # Sets the specified plugin as current plugin
  rgen pl reset                       # Resets the current plugin to none
  rgen pl describe plugin_name        # Describes the specified plugin
  rgen pl add plugin_name va.b.c.dev0 # Adds the plugin of version va.b.c.dev0

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
  if RGen.current_plugin.default
    puts "Current plugin is: #{RGen.current_plugin.name}"
  else
    puts <<-EOT
No plugin set!

To work with an included plugin, set it as current plugin using the following command:
    rgen pl <plugin-name>
    EOT
  end
else
  case input = ARGV.shift
  when 'reset', 'none'
    RGen.current_plugin.default = :none
    puts 'Successfully cleared the default plugin!'
  when 'add'
    plugin_name = ARGV.shift
    version = ARGV.shift
    if plugin_name && version
      RGen.plugins_manager.add(plugin_name, version, options)
    else
      puts 'Zero or less arguments provided!'
    end
  when 'added'
    RGen.plugins_manager.list_added_plugins
  when 'list'
    RGen.plugins_manager.list
  when 'describe'
    puts RGen.plugins_manager.describe(ARGV.shift)
  when 'remove'
    plugin_name = ARGV.shift
    if plugin_name
      RGen.plugins_manager.remove(plugin_name)
    else
      puts 'No plugin name provided!'
    end
  when 'update'
    plugin_name = ARGV.shift
    version = ARGV.shift
    if plugin_name && version
      RGen.plugins_manager.update(plugin_name, version)
    else
      puts 'Zero or less arguments provided!'
    end

  else

    RGen.current_plugin.default = input.to_sym
    puts "#{RGen.current_plugin.default.name} is now set as the current plugin."
  end

end

# def _workspace_plugin_command
#  puts 'local'
# end
#
# def _global_plugin_command
#  puts 'global'
# end

# if RGen.in_application_directory? || RGen.in_application_subdirectory?
#    _workspace_plugin_command
# else
#    _global_plugin_command
# end
