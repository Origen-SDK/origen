require 'fileutils'
module RGen
  class Application
    autoload :Statistics,    'rgen/application/statistics'

    # The Runner is responsible for co-ordinating all compile and generate
    # requests from the command line
    class Runner
      attr_accessor :options

      # Launch RGen, any command which generates an output file should launch from here
      # as it gives a common point for listeners to hook in and to establish output
      # directories and so on.
      #
      # Originally this method was called generate but that is now deprecated in favour
      # of the more generic 'launch' as the RGen feature set has expanded.
      def launch(options = {})
        # Clean up the input from legacy code
        options[:action] = extract_action(options)
        options[:files] = extract_files(options)
        @options = options
        prepare_and_validate_workspace(options)
        if options[:lsf]
          record_invocation(options) do
            prepare_for_lsf
            RGen.app.listeners_for(:before_lsf_submission).each(&:before_lsf_submission)
            expand_lists_and_directories(options[:files], options).each do |file|
              RGen.app.lsf_manager.submit_rgen_job(file, options)
            end
          end
          RGen.log.info ''
          RGen.log.info 'Monitor status of remote jobs via:'
          RGen.log.info '  rgen l'
        else
          RGen.log.info '*' * 70 unless options[:quiet]
          RGen.app.listeners_for(:before_generate).each do |listener|
            if listener.class.instance_method(:before_generate).arity == 0
              listener.before_generate
            else
              listener.before_generate(options)
            end
          end
          if RGen.running_remotely?
            RGen.app.listeners_for(:before_generate_remote).each do |listener|
              if listener.class.instance_method(:before_generate_remote).arity == 0
                listener.before_generate_remote
              else
                listener.before_generate_remote(options)
              end
            end
          else
            RGen.app.listeners_for(:before_generate_local).each do |listener|
              if listener.class.instance_method(:before_generate_local).arity == 0
                listener.before_generate_local
              else
                listener.before_generate_local(options)
              end
            end
          end

          record_invocation(options) do
            case options[:action]
            when :forecast_test_time
              RGen.time.forecast_test_time(options)
            else
              if options[:action] == :program
                RGen.generator.generate_program(expand_lists_and_directories(options[:files], options), options)
              else
                temporary_plugin_from_options = options[:current_plugin]
                expand_lists_and_directories(options[:files], options).each do |file|
                  if temporary_plugin_from_options
                    RGen.current_plugin.temporary = temporary_plugin_from_options
                  end
                  case options[:action]
                  when :compile
                    RGen.generator.compile_file_or_directory(file, options)
                  when :merge
                    RGen.generator.merge_file_or_directory(file, options)
                  when :import_test_time
                    RGen.time.import_test_time(file, options)
                  when :import_test_flow
                    RGen.time.import_test_flow(file, options)
                  else
                    RGen.generator.generate_pattern(file, options)
                  end
                  if temporary_plugin_from_options
                    RGen.current_plugin.default
                  end
                end
              end
            end
          end

          unless options[:quiet]
            RGen.log.info '*' * 70
            stats.print_summary unless options[:action] == :merge
          end
        end
      end
      alias_method :generate, :launch

      def prepare_and_validate_workspace(options = {})
        confirm_production_ready(options)
        prepare_directories(options)
      end

      # Post an invocation to the RGen server for usage statistics tracking.
      #
      # Posting an invocation was found to add ~0.5s to all command times,
      # so here we run it in a separate thread to try and hide it behind
      # the user's command.
      #
      # @api private
      def record_invocation(options)
        record_invocation = false
        begin
          # Only record user invocations at this time, also bypass windows since it seems
          # that threads can't be trusted not to block
          unless RGen.running_remotely? # || RGen.running_on_windows?
            record_invocation = Thread.new do
              RGen.client.record_invocation(options[:action]) if options[:action]
            end
          end
        rescue
          # Don't allow this to kill an rgen command
        end
        yield
        begin
          unless RGen.running_remotely?
            # Wait for a server response, ideally would like to not wait here, but it seems if not
            # then invocation postings can be dropped, especially on windows
            RGen.profile 'waiting for recording invocation' do
              record_invocation.value
            end
          end
        rescue
          # Don't allow this to kill an rgen command
        end
      end

      # The action to take should be set by the action option, but legacy code will pass
      # things like :compile => true, the extract_action method handles the old code
      def extract_action(options)
        return options[:action] if options[:action]
        if options[:compile]
          :compile
        elsif options[:program]
          :program
        elsif options[:job_type] == :merge
          :merge
        else
          :pattern
        end
      end

      # Legacy file references can be input via :pattern, :patterns, etc. this
      # cleans it up and forces them all to be in an array assigned to options[:files]
      def extract_files(options)
        files = [options[:pattern]] + [options[:patterns]] + [options[:file]] + [options[:files]]
        files.flatten!
        files.compact!
        files
      end

      def shutdown
        if RGen.app.stats.failed_files > 0 ||
           RGen.app.stats.failed_patterns > 0
          exit 1
        end
      end

      # Expands any list references in the supplied pattern array and
      # returns an array of pattern names. No guarantee is made to
      # whether the pattern names are valid at this stage.
      # Any duplicates will be removed.
      def expand_lists_and_directories(files, options = {})
        RGen.file_handler.expand_list(files, options)
      end

      def statistics
        @statistics ||= Statistics.new(options)
      end
      alias_method :stats, :statistics

      def prepare_for_lsf
        if options[:lsf]
          # Build an options string for saving with the LSF job that represents this runtime environment
          str = "-t #{RGen.target.file.basename}"
          if RGen.environment.file
            str += " --environment #{RGen.environment.file.basename}"
          end
          if options[:output]
            str += " -o #{options[:output]}"
          end
          if options[:reference]
            str += " -r #{options[:reference]}"
          end
          options[:lsf_option_string] = str
          # Clear the LSF manager job list if specifically requested or if that is the default action and
          # no specific action has been requested
          if options[:lsf_action]
            if options[:lsf_action] == :clear
              RGen.app.lsf_manager.clear_all
            end
          elsif RGen.config.default_lsf_action == :clear
            RGen.app.lsf_manager.clear_all
          end
        end
      end

      def prepare_directories(options = {})
        # When running remotely on the LSF never create directories to
        # prevent race conditions as multiple processes run concurrently,
        # instead assume they were already created by the runner who
        # submitted the job.
        RGen.file_handler.set_output_directory(options.merge(create: RGen.running_locally?))
        RGen.file_handler.set_reference_directory(options.merge(create: RGen.running_locally?))
        tmp = "#{RGen.root}/tmp"
        FileUtils.mkdir(tmp) unless File.exist?(tmp)
        if RGen.running_locally?
          mkdir RGen::Log.log_file_directory
          mkdir "#{RGen.root}/.lsf"
        end
        if options[:lsf]
          mkdir RGen.app.lsf_manager.log_file_directory
        end
      end

      # Make the given directory if it doesn't exist, must be a full path
      def mkdir(dir)
        unless File.exist?(dir)
          FileUtils.mkdir_p(dir)
        end
      end

      def confirm_production_ready(_options = {})
        # The caller would have already verified the status before submission
        if RGen.running_locally?
          if RGen.mode.production?
            RGen.app.cm.ensure_workspace_unmodified!
          end
        end
      end
    end
  end
end
