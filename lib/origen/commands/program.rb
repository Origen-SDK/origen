require 'optparse'
require 'origen/commands/helpers'

options = {}

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: origen p [space separated files or directories] [options]'
  opts.on('-e', '--environment NAME', String, 'Override the default environment, NAME can be a full path or a fragment of an environment file name') { |e| options[:environment] = e }
  opts.on('-t', '--target NAME', String, 'Override the default target, NAME can be a full path or a fragment of a target file name') { |t| options[:target] = t }
  opts.on('-l', '--lsf [ACTION]', [:clear, :add], "Submit jobs to the LSF, optionally specify whether to 'clear' or 'add' to existing jobs") { |a| options[:lsf] = true; options[:lsf_action] = a }
  opts.on('-w', '--wait', 'Wait for LSF processing to complete') { options[:wait_for_lsf_completion] = true }
  opts.on('-c', '--continue', 'Continue on error (to the next file)') { options[:continue] = true }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-f', '--file FILE', String, 'Override the default log file') { |o| options[:log_file] = o }
  opts.on('-pl', '--plugin PLUGIN_NAME', String, 'Set current plugin') { |pl_n|  options[:current_plugin] = pl_n }
  opts.on('-o', '--output DIR', String, 'Override the default output directory') { |o| options[:output] = o }
  opts.on('-r', '--reference DIR', String, 'Override the default reference directory') { |o| options[:reference] = o }
  opts.on('--list FILE', String, 'Override the default pattern list file name') { |o| options[:referenced_pattern_list] = o }
  opts.on('--doc', 'Generate into doc (yaml) format, requires a Doc interface to be setup in your application') { options[:doc] = true }
  opts.on('-q', '--queue NAME', String, 'Specify the LSF queue, default is short') { |o| options[:queue] = o }
  opts.on('-p', '--project NAME', String, 'Specify the LSF project, default is msg.te') { |o| options[:project] = o }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-m', '--mode MODE', Origen::Mode::MODES, 'Force the Origen operating mode:', '  ' + Origen::Mode::MODES.join(', ')) { |_m| }
  # Apply any application option extensions to the OptionParser
  extend_options(opts, app_options, options)
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV
options[:files] = ARGV

Origen.load_application

if options[:queue]
  Origen.config.lsf.queue = options.delete(:queue)
end
if options[:project]
  Origen.config.lsf.project = options.delete(:project)
end

def self._with_doc_tester(options)
  if options[:doc]
    Origen.app.with_doc_tester do
      yield
    end
  else
    yield
  end
end

_with_doc_tester(options) do
  Origen.app.plugins.temporary = options[:current_plugin] if options[:current_plugin]
  Origen.environment.temporary = options[:environment] if options[:environment]
  Origen.target.temporary = options[:target] if options[:target]
  Origen.app.load_target!  # This initial load is required to apply any configuration
  # options present in the target, it will loaded again before
  # each generate/compile job

  if Origen.config.test_program_output_directory && !options[:output]
    options[:output] = Origen.config.test_program_output_directory
  end

  options[:action] = :program  # Let the generator know this is a test program generation
  Origen.app.runner.launch(options)
end

Origen.lsf.wait_for_completion if options[:wait_for_lsf_completion]
