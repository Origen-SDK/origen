module Origen
  class Generator
    module Comparator
      # Will check if the supplied file has changed from the last time it was generated
      # Returns true if it is a new file, or if a change has been detected
      def check_for_changes(new, old, options = {})
        options = {
          comment_char:   Origen.app.tester ? Origen.app.tester.comment_char : nil,
          quiet:          false,
          compile_job:    false,
          suspend_string: 'STOPDIFF',
          resume_string:  'STARTDIFF'
        }.merge(options)

        if File.exist?(old)
          if Utility::Diff.new(file_a: new, file_b: old, ignore_blank_lines: true,
                               comment_char: options[:comment_char],
                               suspend_string: options[:suspend_string],
                               resume_string: options[:resume_string]).diffs?

            unless options[:quiet]
              cmd = "*** CHANGE DETECTED *** To update the reference:  #{Origen.config.copy_command} #{relative_path_to(new)} #{relative_path_to(old)}"
              cmd += ' /Y' if Origen.running_on_windows?
              Origen.log.info cmd
              Origen.log.info "#{Origen.config.diff_command} #{relative_path_to(old)} #{relative_path_to(new)} &"
              Origen.log.info '**********************************************************************'
            end
            if options[:compile_job]
              stats.changed_files += 1
            else
              stats.changed_patterns += 1
            end
            true
          end
        else
          unless options[:quiet]
            Origen.log.info "*** NEW FILE *** To save it:  #{Origen.config.copy_command} #{relative_path_to(new)} #{relative_path_to(old)}"
            Origen.log.info '**********************************************************************'
          end
          if options[:compile_job]
            stats.new_files += 1
          else
            stats.new_patterns += 1
          end
          true
        end
      end

      def stats
        Origen.app.stats
      end

      def relative_path_to(file)
        p = Pathname(file).relative_path_from(Pathname.pwd).to_s
        p.gsub!('/', '\\') if Origen.running_on_windows?
        p
      end
    end
  end
end
