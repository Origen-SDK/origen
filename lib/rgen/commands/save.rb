require 'optparse'

options = {}

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-EOT
Parse the log file and execute all commands to save NEW or CHANGED patterns or files.

Usage: rgen save TYPE [options]
    valid TYPE values: all, new, changed
  EOT
  opts.on('-f', '--file FILE', String, 'Override the default log file') { |o| options[:log_file] = o }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-m', '--mode MODE', RGen::Mode::MODES, 'Force the RGen operating mode:', '  ' + RGen::Mode::MODES.join(', ')) { |_m| }
  app_options.each do |app_option|
    opts.on(*app_option) {}
  end
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV

type = ARGV.first
unless %w(all new changed).include?(type)
  puts "Invalid TYPE parameter supplied, must be 'all', 'new' or 'changed'"
  exit 1
end

if options[:log_file]
  file = "#{RGen.root}/#{options[:log_file]}"
else
  file = RGen::Log.log_file
end

if type == 'new'
  match = /.*(NEW FILE).*(#{RGen.config.copy_command} .*)/
elsif type == 'changed'
  match = /.*(CHANGE DETECTED).*(#{RGen.config.copy_command} .*)/
else
  match = /.*(NEW FILE|CHANGE DETECTED).*(#{RGen.config.copy_command} .*)/
end

File.open(file) do |f|
  f.readlines.each do |line|
    if line =~ match
      system(Regexp.last_match[2])
    end
  end
end

puts 'Reference updated!'

exit 0
