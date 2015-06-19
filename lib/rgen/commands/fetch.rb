require 'optparse'
require 'fileutils'

options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = <<-END
Automatically creates the workspace for the requested rgen plugin and populates the latest version from the server.

By default this will always create the workspace at './[PLUGIN_NAME]'

Usage: rgen fetch [PLUGIN_NAME] [options]
END
  opts.on('-o', '--outputdir', 'User defined destination directory of the plugin workspace') {  options[:debugger] = true }
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end
opt_parser.orig_parse! ARGV
options[:patterns] = ARGV

# Extract user input
plugin_name = ARGV[0]
dir = ARGV[1]

# Set valid_name to false by default
valid_name = false

# If requested plugin is rgen_core or rgen, then run special case, else search through all available plugins
if plugin_name.downcase == 'rgen_core' || plugin_name.downcase == 'rgen'
  plugin_name = 'rgen'
  valid_name = true
  rc_url = RGen.client.rgen[:vault]
else
  RGen.client.plugins.each do |name|
    if name[:rgen_name].downcase == plugin_name.downcase
      valid_name = true
      rc_url = name[:vault]
    end
  end
end

# If valid_name not found, then abort
unless valid_name == true
  puts "The #{plugin_name} plugin which you have requested has not been found, check make sure you have typed in the name correctly"
  puts "To see the list of available plugins, please run 'rgen plugin list' inside an existing rgen workspace"
  exit 1
end

# If user didn't specify directory then configure for default directory
unless dir
  dir = "./#{plugin_name}"
  puts "You did not specify a workspace directory for #{plugin_name} plugin, it will therefore be created at"
  puts "#{dir}"
end

# Checks to see if the destination directory is empty
unless Dir["#{dir}/*"].empty?
  puts 'The requested workspace is not empty, please delete it and try again, or select a different path.'
  exit 1
end

# Set up the requested plugin workspace
rc = RGen::RevisionControl.new remote: rc_url, local: dir
rc.build
