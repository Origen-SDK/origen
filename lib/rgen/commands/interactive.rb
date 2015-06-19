require 'optparse'
require 'irb'
require 'irb/completion'
begin
  require 'pry'
rescue LoadError
  # If not installed simply not available
end

module RGen
  # Methods available to the command line in a console session, split this to a
  # separate file if it gets large over time
  module ConsoleMethods
    def j750
      @_j750 ||= RGen::Tester::J750.new
      @_j750.parser
    end
  end

  # App options are options that the application can supply to extend this command
  app_options = @application_options || []
  options = {}
  opt_parser = OptionParser.new do |opts|
    opts.banner = <<-END
Start an interactive console session with your target.
Usage: rgen i [options]
    END
    opts.on('-e', '--environment NAME', String, 'Override the default environment, NAME can be a full path or a fragment of an environment file name') { |e| options[:environment] = e }
    opts.on('-t', '--target NAME', String, 'Override the default target, NAME can be a full path or a fragment of a target file name') { |t| options[:target] = t }
    opts.on('-pl', '--plugin PLUGIN_NAME', String, 'Set current plugin') { |pl_n|  options[:current_plugin] = pl_n }
    opts.on('-p', '--pry', 'Use Pry for the session (instead of IRB)') { options[:pry] = true }
    opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
    opts.on('-m', '--mode MODE', RGen::Mode::MODES, 'Force the RGen operating mode:', '  ' + RGen::Mode::MODES.join(', ')) { |_m| }
    app_options.each do |app_option|
      opts.on(*app_option) {}
    end
    opts.separator ''
    opts.on('-h', '--help', 'Show this message') { puts opts; exit }
  end
  opt_parser.parse! ARGV

  RGen.load_application
  RGen.current_plugin.temporary = options[:current_plugin] if options[:current_plugin]
  RGen.environment.temporary = options[:environment] if options[:environment]
  RGen.target.temporary = options[:target] if options[:target]
  RGen.app.load_console
  RGen.app.runner.prepare_directories # Ensure tmp et all exist

  if defined?(Pry) && options[:pry]
    include ConsoleMethods
  else
    IRB::ExtendCommandBundle.send :include, RGen::ConsoleMethods
    IRB.start
    exit 0
  end
  # rubocop:disable Debugger, EmptyLines







  binding.pry







  # rubocop:enable Debugger, EmptyLines
end
