module RGen
  class Generator
    # A job is responsible for executing a single pattern source
    class Job # :nodoc: all
      attr_accessor :output_file_body, :pattern

      def initialize(pattern, options)
        @testing = options[:testing]
        @options = options
        @requested_pattern = pattern
        @no_comments = options[:no_comments]
      end

      # Returns true if the job is a test job, will only be true in a test scenario
      def test?
        @testing
      end

      def no_comments?
        @no_comments
      end

      def requested_pattern
        @requested_pattern
      end
      alias_method :requested_file, :requested_pattern

      # Returns a full path to the output pattern, note that this is not available
      # until the job has been run
      def output_pattern
        "#{output_pattern_directory}/#{output_pattern_filename}"
      end
      alias_method :output_file, :output_pattern

      def reference_pattern
        "#{reference_pattern_directory}/#{output_pattern_filename}"
      end
      alias_method :reference_file, :reference_pattern

      def output_pattern_filename
        return '' if @testing
        # If the pattern name has been overridden by an interator use that
        return @output_pattern_filename if @output_pattern_filename
        if !@pattern && !@output_file_body
          fail 'Sorry the output_pattern is not available until the job has been run'
        end
        body = @output_file_body ? @output_file_body : File.basename(@pattern, '.rb')
        output_prefix + body + output_postfix + output_extension
      end

      # This can be modified at runtime by the pattern generator in response to
      # iterator substitutions
      def output_pattern_filename=(val)
        @output_pattern_filename = val
      end

      def reset_output_pattern_filename
        @output_pattern_filename = nil
      end

      def output_pattern_directory
        RGen.file_handler.output_directory
      end

      def reference_pattern_directory
        RGen.file_handler.reference_directory
      end

      def output_prefix
        p = RGen.config.pattern_prefix ? RGen.config.pattern_prefix + '_' : ''
        p = "_#{p}" if RGen.tester.doc?
        p
      end

      def output_postfix
        RGen.config.pattern_postfix ? '_' + RGen.config.pattern_postfix : ''
      end

      def output_extension
        '.' + RGen.tester.pat_extension
      end

      def run
        RGen.app.current_job = self
        begin
          if @options[:compile]
            RGen.generator.compiler.compile(@requested_pattern, @options)
          elsif @options[:job_type] == :merge
            RGen.generator.compiler.merge(@requested_pattern)
          elsif @options[:action] == :program
            RGen.flow.reset
            RGen.resources.reset
            RGen::Tester::Generator.execute_source(@pattern)
          else
            RGen.generator.pattern.reset      # Resets the pattern controller ready for a new pattern
            # Give the app a chance to handle pattern dispatch
            skip = false
            RGen.app.listeners_for(:before_pattern_lookup).each do |listener|
              skip ||= !listener.before_pattern_lookup(@requested_pattern)
            end
            unless skip
              @pattern = RGen.generator.pattern_finder.find(@requested_pattern, @options)
              if @pattern.is_a?(Hash)
                @output_file_body = @pattern[:output]
                @pattern = @pattern[:pattern]
              end
              load @pattern unless @pattern == :skip  # Run the pattern
            end
          end
        rescue Exception => e
          if @options[:continue] || RGen.running_remotely?
            RGen.log.error "FAILED - #{@requested_pattern} (for target #{RGen.target.name})"
            RGen.log.error e.message
            e.backtrace.each do |l|
              RGen.log.error l
            end
            if @options[:compile]
              RGen.app.stats.failed_files += 1
            else
              RGen.app.stats.failed_patterns += 1
            end
          else
            puts e.message
            puts e.backtrace
            exit 1
          end
        end
      end
    end
  end
end
