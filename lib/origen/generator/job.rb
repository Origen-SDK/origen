module Origen
  class Generator
    # A job is responsible for executing a single pattern source
    class Job # :nodoc: all
      attr_accessor :output_file_body, :pattern
      attr_reader :split_counter, :split_names
      attr_reader :options

      def initialize(pattern, options)
        @testing = options[:testing]
        @options = options
        @requested_pattern = pattern
        @no_comments = options[:no_comments]
        @output_opt = options[:output]
      end

      # Returns true if the job is a test job, will only be true in a test scenario
      def test?
        @testing
      end

      def no_comments?
        @no_comments
      end

      def inc_split_counter(name = '')
        @split_counter ||= 0
        @split_names ||= ['']
        @split_counter += 1
        @split_names << name
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
        output_prefix + body + output_postfix + split_number + output_extension
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
        @output_pattern_directory ||= begin
          dir = output_override || Origen.app.config.pattern_output_directory
          if tester.respond_to?(:subdirectory)
            dir = File.join(dir, tester.subdirectory)
          end
          FileUtils.mkdir_p(dir) unless File.exist?(dir)
          dir
        end
      end

      def reference_pattern_directory
        @reference_pattern_directory ||= begin
          dir = Origen.file_handler.reference_directory
          if tester.respond_to?(:subdirectory)
            dir = File.join(dir, tester.subdirectory)
          end
          FileUtils.mkdir_p(dir) unless File.exist?(dir)
          dir
        end
      end

      def output_prefix
        p = Origen.config.pattern_prefix ? Origen.config.pattern_prefix + '_' : ''
        p = "_#{p}" if Origen.tester.doc?
        p
      end

      def output_postfix
        Origen.config.pattern_postfix ? '_' + Origen.config.pattern_postfix : ''
      end

      def output_extension
        '.' + Origen.tester.pat_extension
      end

      def output_override
        if @output_opt
          if @output_opt =~ /#{Origen.root}/
            return @output_opt
          else
            return "#{Origen.root}/#{@output_opt}"
          end
        end
        nil
      end

      def split_number
        if split_counter
          if split_names[split_counter] != ''
            "_#{split_names[split_counter]}"
          else
            "_part#{split_counter}"
          end
        else
          ''
        end
      end

      def strip_dir_and_ext(name)
        Pathname.new(name).basename('.*').basename('.*').to_s
      end

      def run
        Origen.app.current_jobs << self
        begin
          if @options[:compile]
            Origen.log.start_job(strip_dir_and_ext(@requested_pattern), :compiler)
            Origen.generator.compiler.compile(@requested_pattern, @options)
          elsif @options[:job_type] == :merge
            Origen.log.start_job(strip_dir_and_ext(@requested_pattern), :merger)
            Origen.generator.compiler.merge(@requested_pattern)
          elsif @options[:action] == :program
            if Origen.running_simulation?
              Origen.log.start_job(strip_dir_and_ext(@requested_pattern), :simulator)
            else
              Origen.log.start_job(strip_dir_and_ext(@requested_pattern), :program_generator)
            end
            Origen.flow.reset
            Origen.resources.reset
            OrigenTesters::Generator.execute_source(@pattern)
          else
            if Origen.running_simulation?
              Origen.log.start_job(strip_dir_and_ext(@requested_pattern), :simulator)
            else
              Origen.log.start_job(strip_dir_and_ext(@requested_pattern), :pattern_generator)
            end
            Origen.generator.pattern.reset # Resets the pattern controller ready for a new pattern
            # Give the app a chance to handle pattern dispatch
            skip = false
            Origen.app.listeners_for(:before_pattern_lookup).each do |listener|
              skip ||= !listener.before_pattern_lookup(@requested_pattern)
            end
            unless skip
              if @options[:sequence]
                @pattern = @requested_pattern
                Origen.pattern.sequence do |seq|
                  # This splits the pattern name by "_" then removes all values that are common to all patterns
                  # and then rejoins what is left.
                  # The goal is to keep the thread ID concise for the log and rather than using the whole pattern
                  # name only focussing on what is different.
                  # e.g. if you combined patterns flash_read_ckbd_ip1_max.rb and flash_read_ckbd_ip2_max.rb into
                  # a concurrent sequence then the two threads would be called 'ip1' and 'ip2'.
                  ids = @options[:patterns].map do |pat|
                    Pathname.new(pat).basename('.*').to_s.split('_')
                  end
                  ids = ids.map { |id| id.reject { |i| ids.all? { |id| id.include?(i) } }.join('_') }

                  @options[:patterns].each_with_index do |pat, i|
                    id = ids[i]
                    id = i.to_s if id.empty?
                    seq.in_parallel id do
                      seq.run pat
                    end
                  end
                end
              else
                @pattern = Origen.generator.pattern_finder.find(@requested_pattern, @options)
                if @pattern.is_a?(Hash)
                  @output_file_body = @pattern[:output]
                  @pattern = @pattern[:pattern]
                end
                load @pattern unless @pattern == :skip # Run the pattern
              end
            end
          end
        rescue Exception => e
          # Whoever has aborted the job is responsible for cleaning it up
          unless e.is_a?(Origen::Generator::AbortError)
            if @options[:continue] || Origen.running_remotely?
              Origen.log.error "FAILED - #{@requested_pattern} (for target #{Origen.target.name})"
              Origen.log.error e.message
              e.backtrace.each do |l|
                Origen.log.error l
              end
              if @options[:compile]
                Origen.app.stats.failed_files += 1
              else
                Origen.app.stats.failed_patterns += 1
              end
            else
              raise
            end
          end
        end
        Origen.log.stop_job
        Origen.app.current_jobs.pop
      end
    end
  end
end
