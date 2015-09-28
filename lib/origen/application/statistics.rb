module Origen
  class Application
    # Responsible for keeping track of all stats collected during a run
    class Statistics
      attr_accessor :completed_files, :failed_files, :missing_files,
                    :new_files, :changed_files
      attr_accessor :completed_patterns, :failed_patterns, :missing_patterns,
                    :new_patterns, :changed_patterns
      attr_accessor :total_vectors, :total_cycles, :total_duration, :errors

      class Pattern
        attr_accessor :vectors, :cycles, :duration
        def initialize
          @vectors = 0
          @cycles = 0
          @duration = 0
        end
      end

      def initialize(options)
        @options = options
        @patterns = {}
        reset_global_stats
      end

      def reset_global_stats
        @completed_files = 0
        @failed_files = 0
        @missing_files = 0
        @new_files = 0
        @changed_files = 0

        @completed_patterns = 0
        @failed_patterns = 0
        @missing_patterns = 0
        @new_patterns = 0
        @changed_patterns = 0

        @total_vectors = 0
        @total_cycles = 0
        @total_duration = 0

        @errors = 0
      end

      def reset_pattern_stats
      end

      def print_summary
        method = clean_run? ? :success : :info
        if @completed_patterns > 0 || @failed_patterns > 0
          Origen.log.send method, "Total patterns:   #{@completed_patterns}"
          Origen.log.send method, "Total vectors:    #{@total_vectors}"
          Origen.log.send method, 'Total duration:   %.6f' % @total_duration
          Origen.log.send method, "New patterns:     #{@new_patterns}"
          if @changed_patterns > 0
            Origen.log.warn "Changed patterns: #{@changed_patterns}"
          else
            Origen.log.send method, "Changed patterns: #{@changed_patterns}"
          end
          Origen.log.error "FAILED patterns:  #{@failed_patterns}" if @failed_patterns > 0
          Origen.log.info
        end
        if @completed_files > 0 || @failed_files > 0
          Origen.log.send method, "Total files:      #{@completed_files}"
          Origen.log.send method, "New files:        #{@new_files}"
          Origen.log.send method, "Changed files:    #{@changed_files}"
          Origen.log.error "FAILED files:     #{@failed_files}" if @failed_files > 0
          Origen.log.info
        end
        if @errors > 0
          Origen.log.error "ERRORS:           #{@errors}"
        end

        if @changed_files > 0 || @changed_patterns > 0
          changes = true
          Origen.log.info 'To accept all of these changes run:'
          Origen.log.info '  origen save changed'
        end
        if @new_files > 0 || @new_patterns > 0
          news = true
          Origen.log.info 'To save all of these new files as the reference version run:'
          Origen.log.info '  origen save new'
        end
        if changes && news
          Origen.log.info 'To save both new and changed files run:'
          Origen.log.info '  origen save all'
        end
        Origen.log.info '**********************************************************************'
      end

      def summary_text
        <<-END
    Total patterns:   #{@completed_patterns}
    New patterns:     #{@new_patterns}
    Changed patterns: #{@changed_patterns}
    FAILED patterns:  #{@failed_patterns}

    Total files:      #{@completed_files}
    New files:        #{@new_files}
    Changed files:    #{@changed_files}
    FAILED files:     #{@failed_files}

    ERRORS:           #{@errors}
        END
      end

      def clean_run?
        @changed_files == 0 && @changed_patterns == 0 &&
          @new_files == 0 && @new_patterns == 0 &&
          @failed_files == 0 && @failed_patterns == 0 &&
          @errors == 0
      end

      def record_failed_pattern
        @failed_patterns += 1
      end

      def record_missing_pattern
        @missing_patterns += 1
      end

      def add_vector(x = 1)
        current_pattern.vectors += x
      end

      def add_cycle(x = 1)
        current_pattern.cycles += x
      end

      def add_time_in_ns(x)
        current_pattern.duration += x
      end

      def collect_for_pattern(key)
        @pattern_key = key
        yield
        @pattern_key = nil
      end

      def current_pattern
        pattern(@pattern_key)
      end

      def pattern(key)
        @patterns[key] ||= Pattern.new
      end

      def number_of_vectors_for(key)
        pattern(key).vectors
      end

      def number_of_cycles_for(key)
        pattern(key).vectors
      end

      def execution_time_for(key)
        pattern(key).duration.to_f / 1_000_000_000
      end

      def record_pattern_completion(key)
        @completed_patterns += 1
        @total_vectors += number_of_vectors_for(key)
        @total_cycles += number_of_cycles_for(key)
        @total_duration += execution_time_for(key)
      end

      def report_pass
        Origen.log.success ''
        Origen.log.success '    PPPPP      AA        SSSS    SSSS'
        Origen.log.success '    PP  PP    AAAA      SS  SS  SS  SS'
        Origen.log.success '    PPPPP    AA  AA      SS      SS'
        Origen.log.success '    PP      AAAAAAAA       SS      SS'
        Origen.log.success '    PP     AA      AA   SS  SS  SS  SS'
        Origen.log.success '    PP    AA        AA   SSSS    SSSS'
        Origen.log.success ''
        # exit with code 0 on pass
        exit(true)
      end

      def report_fail
        Origen.log.error ''
        Origen.log.error '    FFFFFF     AA       II   LL'
        Origen.log.error '    FF        AAAA      II   LL'
        Origen.log.error '    FFFFF    AA  AA     II   LL'
        Origen.log.error '    FF      AAAAAAAA    II   LL'
        Origen.log.error '    FF     AA      AA   II   LL'
        Origen.log.error '    FF    AA        AA  II   LLLLLL'
        Origen.log.error ''
        # exit with code 1 on fail
        exit(false)
      end
    end
  end
end
