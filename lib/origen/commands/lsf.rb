require 'optparse'
require 'origen/commands/helpers'

include CommandHelpers

options = {}

def require_type_or_id(options)
  unless options[:id] || options[:type]
    puts 'You must supply a job type or ID'
    exit 1
  end
end

# Provides the hook to launch a monitored system command
# on a remote machine. This is intended to be used internally and
# is not part of the public API.
if ARGV.delete('--execute')
  ix = ARGV.index('--id')
  if ix
    ARGV.delete_at(ix)
    id = ARGV[ix]
    ARGV.delete_at(ix)
  else
    puts 'You must supply a job ID to execute'
    exit 1
  end
  ix = ARGV.index('--dependents')
  if ix
    ARGV.delete_at(ix)
    dependents = ARGV[ix].split(',')
    ARGV.delete_at(ix)
  else
    dependents = nil
  end
  Origen.app.lsf_manager.execute_remotely(cmd: ARGV, id: id, dependents: dependents)
  exit 0
end

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-EOT
Manage job submissions to the LSF, with no options will display the current
status summary of all tracked jobs.

Usage: origen lsf [options]
  EOT
  opts.on('-v', '--verbose', 'Show job details') { options[:verbose] = true }
  opts.on('-r', '--resubmit', 'Re-submit jobs') { options[:resubmit] = true }
  opts.on('-c', '--clear', 'Clear jobs') {  options[:clear] = true }
  opts.on('-l', '--log', 'Build a log file from the completed jobs') { options[:log] = true }
  #  opts.on("-k", "--kill", "Kill jobs") { options[:kill] = true }
  types = [:queuing, :running, :lost, :passed, :failed, :all]
  opts.on('-t', '--type TYPE', types, 'Job type to apply the requested action to:', '  ' + types.join(', ')) { |t| options[:type] = t.to_sym }
  opts.on('-i', '--id ID', String, 'Job ID to apply the requested action to') { |t| options[:id] = t }
  opts.on('-w', '--wait', 'Wait for LSF processing to complete') { options[:wait_for_lsf_completion] = true }
  # opts.on("-e", "--execute", "Execute....") { options[:execute] = true }
  opts.on('-m', '--mode MODE', Origen::Mode::MODES, 'Force the Origen operating mode:', '  ' + Origen::Mode::MODES.join(', ')) { |_m| }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  # Apply any application option extensions to the OptionParser
  extend_options(opts, app_options, options)
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV

if options[:clear] || options[:kill] || options[:resubmit]
  require_type_or_id(options)
end

Origen.load_application
Origen.app.lsf_manager.classify_jobs
if options[:clear]
  Origen.app.lsf_manager.clear(options)
  Origen.app.lsf_manager.classify_jobs
end
if options[:resubmit]
  Origen.app.lsf_manager.resubmit(options)
  Origen.app.lsf_manager.classify_jobs
end
# if options[:kill]
#  Origen.app.lsf_manager.kill(options)
#  Origen.app.lsf_manager.classify_jobs
# end
if options[:log]
  Origen.app.lsf_manager.build_log(options)
else
  Origen.app.lsf_manager.print_status(options)
end

Origen.lsf.wait_for_completion if options[:wait_for_lsf_completion]

exit 0
