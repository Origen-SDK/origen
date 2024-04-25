require 'optparse'
require 'irb'
require 'irb/completion'
begin
  require 'pry'
rescue LoadError
  # If not installed simply not available
end
require 'origen/commands/helpers'

module Origen
  # Methods available to the command line in a console session, split this to a
  # separate file if it gets large over time
  module ConsoleMethods
    def ls
      `ls`.split("\n")
    end

    def cd(dir)
      Dir.chdir(dir)
      Dir.pwd
    end

    def pwd
      Dir.pwd
    end
  end

  # App options are options that the application can supply to extend this command
  app_options = @application_options || []
  options = {}
  opt_parser = OptionParser.new do |opts|
    opts.banner = <<-END
Start an interactive console session with your target.
Usage: origen i [options]
    END
    opts.on('-e', '--environment NAME', String, 'Override the default environment, NAME can be a full path or a fragment of an environment file name') { |e| options[:environment] = e }
    opts.on('-t', '--target NAME', String, 'Override the default target, NAME can be a full path or a fragment of a target file name') { |t| options[:target] = t }
    opts.on('-pl', '--plugin PLUGIN_NAME', String, 'Set current plugin') { |pl_n| options[:current_plugin] = pl_n }
    opts.on('-p', '--pry', 'Use Pry for the session (instead of IRB)') { options[:pry] = true }
    opts.on('-d', '--debugger', 'Enable the debugger') { options[:debugger] = true }
    opts.on('-m', '--mode MODE', Origen::Mode::MODES, 'Force the Origen operating mode:', '  ' + Origen::Mode::MODES.join(', ')) { |_m| }
    # Apply any application option extensions to the OptionParser
    Origen::CommandHelpers.extend_options(opts, app_options, options)
    opts.separator ''
    opts.on('-h', '--help', 'Show this message') { puts opts; exit }
  end
  opt_parser.parse! ARGV

  Origen.app.plugins.temporary = options[:current_plugin] if options[:current_plugin]
  Origen.environment.temporary = options[:environment] if options[:environment]
  Origen.target.temporary = options[:target] if options[:target]
  Origen.app.load_target!
  Origen.app.runner.prepare_directories # Ensure tmp et all exist

  Origen.instance_variable_set(:@running_interactively, true)
  listeners_for(:interactive_startup).each(&:interactive_startup)

  begin
    if defined?(Pry) && options[:pry]
      include ConsoleMethods
      # rubocop:disable Lint/Debugger

      binding.pry

      # rubocop:enable Lint/Debugger
    else
      IRB::ExtendCommandBundle.send :include, Origen::ConsoleMethods
      IRB.start
    end
  ensure
    listeners_for(:interactive_shutdown).each(&:interactive_shutdown)
  end
end
