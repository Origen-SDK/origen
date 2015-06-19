require 'optparse'

options = {}

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: rgen p [space separated files or directories] [options]'
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
  opts.on('-m', '--mode MODE', RGen::Mode::MODES, 'Force the RGen operating mode:', '  ' + RGen::Mode::MODES.join(', ')) { |_m| }
  app_options.each do |app_option|
    opts.on(*app_option) {}
  end
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV
options[:files] = ARGV

RGen.load_application

if options[:queue]
  RGen.config.lsf.queue = options.delete(:queue)
end
if options[:project]
  RGen.config.lsf.project = options.delete(:project)
end

def self._with_doc_tester(options)
  if options[:doc]
    RGen.app.with_doc_tester do
      yield
    end
  else
    yield
  end
end

_with_doc_tester(options) do
  RGen.current_plugin.temporary = options[:current_plugin] if options[:current_plugin]
  RGen.environment.temporary = options[:environment] if options[:environment]
  RGen.target.temporary = options[:target] if options[:target]
  RGen.app.load_target!  # This initial load is required to appply any configuration
  # options present in the target, it will loaded again before
  # each generate/compile job

  if RGen.config.test_program_output_directory && !options[:output]
    options[:output] = RGen.config.test_program_output_directory
  end

  options[:action] = :program  # Let the generator know this is a test program generation
  RGen.app.runner.launch(options)
end

RGen.lsf.wait_for_completion if options[:wait_for_lsf_completion]
