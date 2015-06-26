require 'optparse'
require 'fileutils'

options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = <<-END
Automatically creates the workspace for the requested origen plugin and populates the latest version from the server.

By default this will always create the workspace at './[PLUGIN_NAME]'

Usage: origen fetch [PLUGIN_NAME] [options]
END
  opts.on('-o', '--outputdir', 'User defined destination directory of the plugin workspace') {  options[:debugger] = true }
  opts.on('-v', '--version', 'User requested plugin/gem version') {  options[:debugger] = true }
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

# always the first argument
@plugin_name = ARGV[0]

(1..(ARGV.size)).each do |i|
  @dir = ARGV[i + 1] if ARGV[i] == '-o'
  @version = ARGV[i + 1] if ARGV[i] == '-v'
end

opt_parser.orig_parse! ARGV
options[:patterns] = ARGV

# Extract user input
plugin_name = ARGV[0]
dir = ARGV[1]

# Set valid_name to false by default
valid_name = false

# If requested plugin is origen_core or origen, then run special case, else search through all available plugins
if @plugin_name.downcase == 'origen_core' || @plugin_name.downcase == 'origen'
  @plugin_name = 'origen'
  valid_name = true
  rc_url = Origen.client.origen[:vault]
else
  Origen.client.plugins.each do |name|
    if name[:origen_name].downcase == @plugin_name.downcase
      valid_name = true
      rc_url = name[:vault]
    end
  end
end

# If valid_name not found, then abort
unless valid_name == true
  puts "The #{@plugin_name} plugin which you have requested has not been found, check make sure you have typed in the name correctly"
  puts "To see the list of available plugins, please run 'origen plugin list' inside an existing origen workspace"
  exit 1
end

# If user didn't specify directory then configure for default directory
unless dir
  dir = "./#{@plugin_name}"
  puts "You did not specify a workspace directory for #{plugin_name} plugin, it will therefore be created at"
  puts "#{@dir}"
end

# Checks to see if the destination directory is empty
unless Dir["#{@dir}/*"].empty?
  puts 'The requested workspace is not empty, please delete it and try again, or select a different path.'
  exit 1
end

# Set up the requested plugin workspace
rc = Origen::RevisionControl.new remote: rc_url, local: @dir
rc.build version: @version
