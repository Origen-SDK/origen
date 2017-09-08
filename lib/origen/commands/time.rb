require 'optparse'
require 'pathname'
require 'origen/commands/helpers'

options = {}

ARGV << '-h' if ARGV.empty?

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-STOP
Origen test time profiling and forecasting tools.

Usage: origen time CMD [args] [options]
  CMD - The command to run, the following commands exist:

        import FILE - Import a reference test time from the given detailed execution time file

        forecast - Forecast the test time for the current target for the given flow and library

        new rules   - Create a new rules file (use this to specify how tests should scale between targets)
        new filter  - Create a new filter (use this to filter imports, by default all tests are imported)

  STOP
  opts.on('-n', '--name FILE', String, 'Use the given named reference instead of the default') { |o| options[:ref_name] = o }
  opts.on('-s', '--summary', 'Output flow summary results only (instead of details for each test)') {  options[:summary] = true }
  opts.on('-t', '--target NAME1,NAME2,NAME3', Array, 'Override the default target, NAME can be a full path or a fragment of a target file name') { |t| options[:target] = t }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-m', '--mode MODE', Origen::Mode::MODES, 'Force the Origen operating mode:', '  ' + Origen::Mode::MODES.join(', ')) { |_m| }
  opts.on('-f', '--file FILE', String, 'Override the default log file') { |o| options[:log_file] = o }
  # Apply any application option extensions to the OptionParser
  Origen::CommandHelpers.extend_options(opts, app_options, options)
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end
opt_parser.parse! ARGV

cmd = ARGV[0] || 'missing'
case cmd.downcase
when 'forecast'
  Origen.target.loop(options) do |options|
    Origen.app.runner.launch(action:   :forecast_test_time,
                             summary:  options[:summary],
                             ref_name: options[:ref_name])
  end

when 'import'
  if !ARGV[1] || !File.exist?(ARGV[1])
    puts 'A valid file to import must be supplied, e.g.'
    puts '  origen time import exec_times/p2_sort1.txt'
    exit 1
  end
  if options[:target] && [options[:target]].flatten.size > 1
    puts "When importing it doesn't make sense to select multiple targets,"
    puts 'select only the single target that matches the setup from which'
    puts 'the detailed execution time has been generated!'
    exit 1
  end
  Origen.target.loop(options) do |options|
    # This step seems redundant, the flow should be imported at the
    # same time as extracting the test times
    Origen.app.runner.launch(action:   :import_test_flow,
                             file:     ARGV[1],
                             ref_name: options[:ref_name])

    Origen.app.runner.launch(action:   :import_test_time,
                             file:     ARGV[1],
                             ref_name: options[:ref_name])
  end

when 'new'
  if ARGV[1] == 'rules'
    Origen.app.runner.launch(action:            :compile,
                             file:              "#{Origen.top}/templates/time/rules.rb.erb",
                             output:            "#{Origen.root}/config/test_time",
                             quiet:             true,
                             check_for_changes: false
                            )
    # Add this to the environment if not already present...
    env = "#{Origen.root}/config/environment.rb"
    unless File.readlines(env).any? { |l| l =~ /config\/test_time\/rules/ }
      # The 'b' here invokes binary format and stops Ruby from substituting the \n for a
      # windows carriage return when running on windows
      File.open(env, 'ab') { |f| f.print "require \"\#{Origen.root}/config/test_time/rules\"\n" }
      env = false
    end
    puts ''
    puts 'New rules created at: config/test_time/rules.rb'
    puts ''
    unless env
      puts 'This file has been added to your environment.rb'
      puts ''
    end
    puts 'To check this in run:'
    puts "  dssc ci -new -keep -com \"Initial\" #{Origen.root}/config/test_time/rules.rb"
  elsif ARGV[1] == 'filter'
    Origen.app.runner.launch(action:            :compile,
                             file:              "#{Origen.top}/templates/time/filter.rb.erb",
                             output:            "#{Origen.root}/config/test_time",
                             quiet:             true,
                             check_for_changes: false
                            )
    # Add this to the environment if not already present...
    env = "#{Origen.root}/config/environment.rb"
    unless File.readlines(env).any? { |l| l =~ /config\/test_time\/filter/ }
      File.open(env, 'ab') { |f| f.print "require \"\#{Origen.root}/config/test_time/filter\"\n" }
      env = false
    end
    puts ''
    puts 'New filter created at: config/test_time/filter.rb'
    puts ''
    unless env
      puts 'This file has been added to your environment.rb'
      puts ''
    end
    puts 'To check this in run:'
    puts "  dssc ci -new -keep -com \"Initial\" #{Origen.root}/config/test_time/filter.rb"

  else
    puts 'A valid identifier for the kind of file to create must be supplied, e.g.'
    puts '  origen time new rules'
    exit 1
  end
else
  puts "Unknown command, see 'origen time -h' for a list of commands"
end
