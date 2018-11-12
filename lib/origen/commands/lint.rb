require 'origen/commands/helpers'

options = {}

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-END
Run Ruby lint and style checks on your application code.

Usage: origen lint [space separated files, or directories] [options]

All options and the default files to test can be overridden via the
lint_test application configuration parameter, see here for more info:

http://origen.freescale.net/origen/latest/guides/utilities/lint/

  END
  opts.on('-c', '--correct', 'Correct errors automatically where possible') { options[:correct] = true }
  opts.on('-n', '--no-correct', "Don't correct errors automatically (override if the app default is set to auto correct)") { options[:no_correct] = true }
  opts.on('-e', '--easy', 'Be less strict, most checks run with this flag enabled can be corrected automatically') { options[:easy] = true }
  opts.on('-m', '--mode MODE', Origen::Mode::MODES, 'Force the Origen operating mode:', '  ' + Origen::Mode::MODES.join(', ')) { |_m| }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  # Apply any application option extensions to the OptionParser
  Origen::CommandHelpers.extend_options(opts, app_options, options)
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV
if ARGV.empty?
  if Origen.config.lint_test[:files]
    files = Origen.config.lint_test[:files].map { |f| "#{Origen.root}/#{f}" }.join(' ')
  else
    files = "#{Origen.root}/lib"
  end
else
  files = ARGV.join(' ')
end

if options[:easy] || Origen.config.lint_test[:level] == :easy
  config = "#{Origen.top}/config/rubocop/easy.yml"
else
  config = "#{Origen.top}/config/rubocop/strict.yml"
end

command = "rubocop #{files} --config #{config} --display-cop-names"

unless options[:no_correct]
  if options[:correct] || Origen.config.lint_test[:auto_correct]
    command += ' --auto-correct'
  end
end

if Origen.debugger_enabled?
  command += ' --debug'
end

puts command
result = system(command)

if result == true
  exit 0
elsif result == false
  exit 1
else
  exit 1
end
