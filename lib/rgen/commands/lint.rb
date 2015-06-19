options = {}

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-END
Run Ruby lint and style checks on your application code.

Usage: rgen lint [space separated files, or directories] [options]

All options and the default files to test can be overridden via the
lint_test application configuration parameter, see here for more info:

http://rgen.freescale.net/rgen/latest/guides/utilities/lint/

  END
  opts.on('-c', '--correct', 'Correct errors automatically where possible') { options[:correct] = true }
  opts.on('-n', '--no-correct', "Don't correct errors automatically (override if the app default is set to auto correct)") { options[:no_correct] = true }
  opts.on('-e', '--easy', 'Be less strict, most checks run with this flag enabled can be corrected automatically') { options[:easy] = true }
  opts.on('-m', '--mode MODE', RGen::Mode::MODES, 'Force the RGen operating mode:', '  ' + RGen::Mode::MODES.join(', ')) { |_m| }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  app_options.each do |app_option|
    opts.on(*app_option) {}
  end
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV
if ARGV.empty?
  if RGen.config.lint_test[:files]
    files = RGen.config.lint_test[:files].map { |f| "#{RGen.root}/#{f}" }.join(' ')
  else
    files = "#{RGen.root}/lib"
  end
else
  files = ARGV.join(' ')
end

if options[:easy] || RGen.config.lint_test[:level] == :easy
  config = "#{RGen.top}/config/rubocop/easy.yml"
else
  config = "#{RGen.top}/config/rubocop/strict.yml"
end

command = "rubocop #{files} --config #{config} --display-cop-names"

unless options[:no_correct]
  if options[:correct] || RGen.config.lint_test[:auto_correct]
    command += ' --auto-correct'
  end
end

if RGen.debugger_enabled?
  command += ' --debug'
end

puts command
result = system(command)

if result == true
  exit 0
elsif result == false
  exit 1
else
  begin
    if gem 'rubocop'
      if RGen.running_on_linux? && !File.exist?("#{RGen.top}/.bin/rubocop")
        puts ''
        puts 'It looks like you need to update your toolset to fix the above error, try running these commands before trying again:'
        puts ''
        puts "  pushd #{RGen.top}"
        puts '  source source_setup update'
        puts '  popd'
        puts ''
      end
    end
  rescue Gem::LoadError
    require_gem 'rubocop', version: '0.20.1'
  end
  exit 1
end
