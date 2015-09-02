require 'optparse'

options = {}

# App options are options that the application can supply to extend this command
# app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-EOT
Usage:  origen pl
        origen pl [plugin name]
        origen pl [CMD] [options]

Quickstart Examples:
  origen pl                             # Displays the current plugin
  origen pl added                       # Lists the included plugins
  origen pl [plugin_name]               # Sets the specified plugin as current plugin
  origen pl reset                       # Resets the current plugin to none

The following commands are available:

  added                               Displays all plugins that are currently included in this app locally

The following options are available:
  EOT
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV

if !ARGV[0]
  if Origen.app.plugins.current
    puts "Current plugin is: #{Origen.app.plugins.current.name}"
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
    Origen.app.plugins.current = nil
    puts 'Successfully cleared the default plugin!'
  # when 'add'
  #  plugin_name = ARGV.shift
  #  version = ARGV.shift
  #  if plugin_name && version
  #    Origen.plugins_manager.add(plugin_name, version, options)
  #  else
  #    puts 'Zero or less arguments provided!'
  #  end
  when 'added'
    puts 'The following plugins are included in this app:'
    puts
    format = "%30s\t%30s\t%30s\n"
    printf(format, 'Origen_Name', 'Name', 'Version')
    printf(format, '---------', '----', '-------')

    Origen.app.plugins.sort_by { |p| p.name.to_s }.each do |plugin|
      printf(format, plugin.name, plugin.config.name, plugin.version)
    end
    puts
    exit 0

  # when 'list'
  #  Origen.plugins_manager.list
  # when 'describe'
  #  puts Origen.plugins_manager.describe(ARGV.shift)
  # when 'remove'
  #  plugin_name = ARGV.shift
  #  if plugin_name
  #    Origen.plugins_manager.remove(plugin_name)
  #  else
  #    puts 'No plugin name provided!'
  #  end
  # when 'update'
  #  plugin_name = ARGV.shift
  #  version = ARGV.shift
  #  if plugin_name && version
  #    Origen.plugins_manager.update(plugin_name, version)
  #  else
  #    puts 'Zero or less arguments provided!'
  #  end

  else

    Origen.app.plugins.current = input.to_sym
    if Origen.app.plugins.current
      puts "#{Origen.app.plugins.current.name} is now set as the current plugin."
    else
      puts "#{input} is not among this application's plugins, the current plugin is currently cleared!"
    end
  end

end
