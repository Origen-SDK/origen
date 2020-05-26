module Origen
  class Application
    # This class is responsible for co-ordinating and monitoring all submissions
    # to the LSF. This is in contrast to Origen::Application::LSF which is an API for
    # talking to the LSF.
    class LSFManager
      include Callbacks

      # This will be set by the command dispatcher to reflect the currently executing
      # command. If LSF jobs are spawned with the same command then any options passed
      # to the parent command will automatically be forwarded to the children.
      attr_accessor :current_command

      def initialize
        unless File.exist?(log_file_directory)
          FileUtils.mkdir_p(log_file_directory)
        end
      end

      # Picks and returns either the application's LSF instance or the global LSF instance
      def lsf
        if Origen.running_globally?
          Origen.lsf!
        else
          Origen.app.lsf
        end
      end

      def remote_jobs_file
        "#{Origen.root}/.lsf/remote_jobs"
      end

      # Waits for all jobs to complete, will retry lost jobs (optionally
      # failed jobs).
      #
      # Alternatively supply an :id or an array of :ids to wait only
      # for specific job(s) to complete.
      def wait_for_completion(options = {})
        options = {
          max_lost_retries:         10,
          max_fail_retries:         0,
          poll_duration_in_seconds: 10,
          timeout_in_seconds:       3600
        }.merge(options)
        options[:start_time] ||= Time.now
        if Time.now - options[:start_time] < options[:timeout_in_seconds]
          # When waiting for ids we will hold by monitoring for the result
          # files directly, rather than using the generatic classify routine.
          # This is because the most common use case for this is when jobs
          # are idling remotely on the LSF and don't want to run into contention
          # issues when multiple processes try to classify/save the status.
          if options[:id] || options[:ids]
            ids = extract_ids([options[:id], options[:ids]].flatten.compact)
            if ids.any? { |id| job_running?(id) }
              sleep options[:poll_duration_in_seconds]
              wait_for_completion(options)
            end

          else
            classify_jobs
            print_status(print_insructions: false)
            sleep options[:poll_duration_in_seconds]
            classify_jobs
            resumitted = false
            lost_jobs.each do |job|
              if job[:submissions] < options[:max_lost_retries] + 1
                resubmit_job(job)
                resumitted = true
              end
            end
            failed_jobs.each do |job|
              if job[:submissions] < options[:max_fail_retries] + 1
                resubmit_job(job)
                resumitted = true
              end
            end
            classify_jobs
            if outstanding_jobs? || resumitted
              wait_for_completion(options)
            else
              print_status
            end
          end
        end
      end

      def print_status(options = {})
        options = {
          print_insructions: true
        }.merge(options)
        if options[:verbose]
          print_details(options)
        end
        Origen.log.info ''
        Origen.log.info 'LSF Status'
        Origen.log.info '----------'
        Origen.log.info "Queuing:    #{queuing_jobs.size}"
        Origen.log.info "Running:    #{running_jobs.size}"
        Origen.log.info "Lost:       #{lost_jobs.size}"
        Origen.log.info ''
        Origen.log.info "Passed:     #{passed_jobs.size}"
        Origen.log.info "Failed:     #{failed_jobs.size}"
        Origen.log.info ''
        if options[:print_insructions]
          Origen.log.info 'Common tasks'
          Origen.log.info '------------'
          if queuing_jobs.size > 0
            Origen.log.info 'Queuing'
            Origen.log.info ' Show details: origen l -v -t queuing'
            Origen.log.info ' Re-submit:    origen l -r -t queuing'
          end
          if running_jobs.size > 0
            Origen.log.info 'Running'
            Origen.log.info ' Show details: origen l -v -t running'
            Origen.log.info ' Re-submit:    origen l -r -t running'
          end
          if lost_jobs.size > 0
            Origen.log.info 'Lost'
            Origen.log.info ' Show details: origen l -v -t lost'
            Origen.log.info ' Re-submit:    origen l -r -t lost'
          end
          if passed_jobs.size > 0
            Origen.log.info 'Passed'
            Origen.log.info ' Build log:    origen l -l'
          end
          if failed_jobs.size > 0
            Origen.log.info 'Failed'
            Origen.log.info ' Show details: origen l -v -t failed'
            Origen.log.info ' Re-submit:    origen l -r -t failed'
          end
          Origen.log.info ''
          Origen.log.info 'Reset the LSF manager (clear all jobs): origen lsf -c -t all'
          Origen.log.info ''
        end
      end

      def print_details(options = {})
        if options[:id]
          Origen.log.info "Job: #{options[:id]}"
          Origen.log.info '----' + '-' * options[:id].length
          print_details_of(remote_jobs[options[:id]])
        else
          options[:type] ||= :all
          if options[:type] == :all || options[:type] == :queuing
            Origen.log.info ''
            Origen.log.info 'Queuing'
            Origen.log.info '-------'
            queuing_jobs.each { |j| print_details_of(j) }
          end
          if options[:type] == :all || options[:type] == :running
            Origen.log.info ''
            Origen.log.info 'Running'
            Origen.log.info '-------'
            running_jobs.each { |j| print_details_of(j) }
          end
          if options[:type] == :all || options[:type] == :lost
            Origen.log.info ''
            Origen.log.info 'Lost'
            Origen.log.info '----'
            lost_jobs.each { |j| print_details_of(j) }
          end
          if options[:type] == :all || options[:type] == :passed
            Origen.log.info ''
            Origen.log.info 'Passed'
            Origen.log.info '------'
            passed_jobs.each { |j| print_details_of(j) }
          end
          if options[:type] == :all || options[:type] == :failed
            Origen.log.info ''
            Origen.log.info 'Failed'
            Origen.log.info '------'
            failed_jobs.each { |j| print_details_of(j) }
          end
        end
      end

      def print_details_of(job)
        Origen.log.info "#{job[:command]} #{job[:switches]}".gsub(' --exec_remote', '')
        Origen.log.info "ID: #{job[:id]}"
        Origen.log.info "Submitted: #{time_ago(job[:submitted_at])}"
        Origen.log.info ''
      end

      def time_ago(time)
        seconds = (Time.now - time).to_i
        if seconds < 60
          unit = 'second'
          number = seconds
        elsif seconds < 3600
          unit = 'minute'
          number = seconds / 60
        elsif seconds < 86_400
          unit = 'hour'
          number = seconds / 3600
        else
          unit = 'day'
          number = seconds / 86_400
        end
        "#{number} #{unit}#{number > 1 ? 's' : ''} ago"
      end

      def outstanding_jobs?
        (running_jobs + queuing_jobs).size > 0
      end

      # Clear jobs from memory
      def clear(options)
        if options[:type]
          if options[:type] == :all
            File.delete(remote_jobs_file) if File.exist?(remote_jobs_file)
            @remote_jobs = {}
            return
          else
            send("#{options[:type]}_jobs").each do |job|
              remote_jobs.delete(job[:id])
            end
          end
        else
          remote_jobs.delete(options[:id])
        end
      end

      def clear_all
        File.delete(remote_jobs_file) if File.exist?(remote_jobs_file)
        if File.exist?(log_file_directory)
          FileUtils.rm_rf(log_file_directory)
        end
        FileUtils.mkdir_p(log_file_directory)
        @remote_jobs = {}
        clear_caches
      end

      # Resubmit jobs
      def resubmit(options)
        if options[:type]
          if options[:type] == :all
            remote_jobs.each do |_id, job|
              resubmit_job(job)
            end
          else
            send("#{options[:type]}_jobs").each do |job|
              resubmit_job(job)
            end
          end
        else
          resubmit_job(remote_jobs[options[:id]])
        end
      end

      def stats
        Origen.app.stats
      end

      # Build the log file from the completed jobs
      def build_log(options = {})
        log_method = options[:log_file] ? options[:log_file] : :info
        Origen.log.send(log_method, '*' * 70)
        completed_jobs.each do |job|
          File.open(log_file(job[:id])) do |f|
            last_line_blank = false
            f.readlines.each do |line|
              # Capture and combine the per job stats that look like this:
              #   Total patterns:   1              1347      0.003674
              #   New patterns:     0
              #   Changed patterns: 1
              #   FAILED patterns:  1
              #   Total files:      1
              #   New files:        0
              #   Changed files:    0
              #   FAILED files:     1
              begin
                line.gsub!(/\e\[\d+m/, '')  # Remove any coloring
                if line =~ /Total patterns:\s+(\d+)/
                  stats.completed_patterns += Regexp.last_match[1].to_i
                elsif line =~ /Total vectors:\s+(\d+)/
                  stats.total_vectors += Regexp.last_match[1].to_i
                elsif line =~ /Total duration:\s+(\d+\.\d+)/
                  stats.total_duration += Regexp.last_match[1].to_f
                elsif line =~ /Total files:\s+(\d+)/
                  stats.completed_files += Regexp.last_match[1].to_i
                elsif line =~ /Changed patterns:\s+(\d+)/
                  stats.changed_patterns += Regexp.last_match[1].to_i
                elsif line =~ /Changed files:\s+(\d+)/
                  stats.changed_files += Regexp.last_match[1].to_i
                elsif line =~ /New patterns:\s+(\d+)/
                  stats.new_patterns += Regexp.last_match[1].to_i
                elsif line =~ /New files:\s+(\d+)/
                  stats.new_files += Regexp.last_match[1].to_i
                elsif line =~ /FAILED patterns:\s+(\d+)/
                  stats.failed_patterns += Regexp.last_match[1].to_i
                elsif line =~ /FAILED files:\s+(\d+)/
                  stats.failed_files += Regexp.last_match[1].to_i
                elsif line =~ /ERROR!/
                  stats.errors += 1
                  Origen.log.send :relog, line, options
                else
                  # Compress multiple blank lines
                  if line =~ /^\s*$/ || line =~ /.*\|\|\s*$/
                    unless last_line_blank
                      Origen.log.send(log_method, nil)
                      last_line_blank = true
                    end
                  else
                    # Screen std origen output
                    unless line =~ /  origen save/ ||
                           line =~ /Insecure world writable dir/ ||
                           line =~ /To save all of/
                      line.strip!
                      Origen.log.send :relog, line, options
                      last_line_blank = false
                    end
                  end
                end
              rescue
                # Sometimes illegal UTF-8 characters can get into crash dumps, if this
                # happens just print the line out rather than die
                Origen.log.error line
              end
            end
          end
        end
        Origen.log.send(log_method, '*' * 70)
        stats.print_summary
      end

      # Returns the logfile that should be used by a given process on the LSF, this
      # should be be guaranteed to be unique
      def log_file(id)
        "#{log_file_directory}/#{log_file_name(id)}"
      end

      def passed_file(id)
        "#{log_file_directory}/#{log_file_name(id)}.passed"
      end

      def started_file(id)
        "#{log_file_directory}/#{log_file_name(id)}.started"
      end

      def failed_file(id)
        "#{log_file_directory}/#{log_file_name(id)}.failed"
      end

      def log_file_name(id)
        # host = `hostname`.strip
        "#{id}.txt"
      end

      def log_file_directory
        "#{Origen.root}/.lsf/remote_logs"
      end

      # Register that the given job ID has completed successfully on the LSF
      def job_passed(id)
        `touch #{passed_file(id)}`
      end

      # Register that the given job ID has failed on the LSF
      def job_failed(id)
        `touch #{failed_file(id)}`
      end

      def job_started(id)
        `touch #{started_file(id)}`
      end

      def resubmit_job(job)
        [log_file(job[:id]), passed_file(job[:id]), failed_file(job[:id]), started_file(job[:id])].each do |file|
          FileUtils.rm_f(file) if File.exist?(file)
        end
        job[:lsf_id] = lsf.submit(command_prefix(job[:id], job[:dependents_ids]) + job[:command] + job[:switches], dependents: job[:dependents_lsf_ids])
        job[:status] = nil
        job[:completed_at] = nil
        job[:submitted_at] = Time.now
        job[:submissions] += 1
      end

      def submit_job(command, options = {})
        options = {
          lsf_option_string: ''
        }.merge(options)
        switches = [' ', options[:lsf_option_string], command_options(command)].flatten.compact.join(' ')
        id = generate_job_id
        dependents_ids = extract_ids([options[:depend], options[:depends], options[:dependent], options[:dependents]].flatten.compact)
        dependents_lsf_ids = dependents_ids.map { |dep_id| remote_jobs[dep_id][:lsf_id] }
        lsf_id = lsf.submit(command_prefix(id, dependents_ids) + command + switches, dependents: dependents_lsf_ids)
        job_attrs = {
          id:                 id,
          lsf_id:             lsf_id,
          command:            command,
          submitted_at:       Time.now,
          submissions:        1,
          switches:           switches,
          dependents_ids:     dependents_ids,
          dependents_lsf_ids: dependents_lsf_ids
        }
        remote_jobs[id] = job_attrs
      end

      def extract_ids(jobs_or_ids)
        jobs_or_ids.map { |j| j.is_a?(Hash) ? j[:id] : j }
      end

      def submit_origen_job(cmd, options = {})
        if options[:action]
          action = options[:action] == :pattern ? ' generate' : " #{options[:action]}"
        else
          action = ''
        end

        str = "#{action} #{cmd}".strip
        str.sub!('origen ', '') if str =~ /^origen /

        # Append the --exec_remote switch to all Origen commands, this allows command
        # processing to be altered based on whether it is running locally or
        # remotely by testing Origen.running_remotely?
        str += ' --exec_remote'

        submit_job("origen #{str}", options)
      end

      def command_prefix(id, dependents)
        # define prefix as a blank string if Origen.site_config.lsf_command_prefix is not defined
        if Origen.site_config.lsf_command_prefix
          prefix = Origen.site_config.lsf_command_prefix
        else
          prefix = ''
        end
        prefix += "cd #{Origen.root}; origen l --execute --id #{id} "
        unless dependents.empty?
          prefix += "--dependents #{dependents.join(',')} "
        end
        prefix
      end

      def command_options(command_str)
        command_str.sub(/origen\s*/, '') =~ /(\w+)/
        command = Regexp.last_match[1]
        command = ORIGEN_COMMAND_ALIASES[command] || command
        if command == current_command
          @command_options
        else
          ''
        end
      end

      # This will be called by the command dispatcher to record any options that were passed
      # in when launching the current command.
      # These will be automatically appended if the current command spawns any LSF jobs that
      # will invoke the same command.
      def command_options=(opts)
        # Ensure these options are removed, these are either incompatible with the LSF,
        # or will already have been added elsewhere
        {
          ['-h', '--help']        => false,
          ['-w', '--wait']        => false,
          ['-d', '--debug']       => false,
          ['-c', '--continue']    => false,
          '--exec_remote'         => false,
          ['-t', '--target']      => '*',
          ['-e', '--environment'] => '*',
          '--id'                  => '*',
          ['-l', '--lsf']         => %w(add clear)
        }.each do |names, values|
          [names].flatten.each do |name|
            ix = opts.index(name)
            if ix
              opts.delete_at(ix)
              [values].flatten.each do |value|
                if value && (value == '*' || opts[ix] == value)
                  opts.delete_at(ix)
                end
              end
            end
          end
        end
        @command_options ||= []
        @command_options += opts
      end

      def add_command_option(*opts)
        @command_options ||= []
        @command_options += opts
      end

      def remote_jobs
        @remote_jobs ||= restore_remote_jobs || {}
      end

      def classify_jobs
        clear_caches
        queuing_job_ids = lsf.queuing_job_ids
        running_job_ids = lsf.running_job_ids
        remote_jobs.each do |_id, job|
          # If the status has already been determined send it straight to the bucket
          if job[:status]
            send("#{job[:status]}_jobs") << job
          else
            if job[:lsf_id] == :error
              job[:status] = :lost
              lost_jobs << job
            elsif job_completed?(job[:id])
              if job_passed?(job[:id])
                job[:status] = :passed
                passed_jobs << job
              elsif job_failed?(job[:id])
                job[:status] = :failed
                failed_jobs << job
              end
            else
              if running_job_ids.include?(job[:lsf_id])
                running_jobs << job
                # Once we have assigned a job as running make sure the job is marked as started
                # It can flicker back to queued if the started file takes a long time to arrive
                # from the remote host
                job_started(job[:lsf_id])
              elsif queuing_job_ids.include?(job[:lsf_id])
                queuing_jobs << job
              elsif job_started?(job[:id])
                # There can be considerable latency between the job writing the passed/failed
                # file remotely and it showing up on the local machine.
                # Give some buffer to that before declaring the file lost.
                if job[:completed_at]
                  if (Time.now - job[:completed_at]) < 60
                    running_jobs << job
                  else
                    lost_jobs << job
                  end
                else
                  job[:completed_at] = Time.now
                  running_jobs << job
                end
              # Give jobs submitted less than a minute ago the benefit of the
              # doubt, they may not have shown up in bjobs yet
              elsif (Time.now - job[:submitted_at]) < 60
                queuing_jobs << job
              else
                lost_jobs << job
              end
            end
          end
        end
      end

      def clear_caches
        @running_jobs = nil
        @queuing_jobs = nil
        @passed_jobs = nil
        @failed_jobs = nil
        @lost_jobs = nil
      end

      def running_jobs
        @running_jobs ||= []
      end

      def queuing_jobs
        @queuing_jobs ||= []
      end

      def completed_jobs
        passed_jobs + failed_jobs
      end

      def passed_jobs
        @passed_jobs ||= []
      end

      # Failed jobs are those that started to produce a log file but did not complete
      def failed_jobs
        @failed_jobs ||= []
      end

      # Lost jobs are ones that for whatever reason did not start, or at least get far
      # enough to log that they started
      def lost_jobs
        @lost_jobs ||= []
      end

      # Returns trus if the given job ID generated a complete file when run on the LSF.
      # The complete file is created at the end of a job run and its presence indicates
      # that the job ran and got past the generation/compile stage without crashing.
      def job_completed?(id)
        job_started?(id) &&
          (job_passed?(id) || job_failed?(id))
      end

      def job_running?(id)
        !job_completed?(id)
      end

      def job_started?(id)
        File.exist?(started_file(id))
      end

      def job_passed?(id)
        File.exist?(passed_file(id))
      end

      def job_failed?(id)
        File.exist?(failed_file(id))
      end

      def generate_job_id
        "#{Time.now.to_f}".gsub('.', '')
      end

      def restore_remote_jobs
        if File.exist?(remote_jobs_file)
          File.open(remote_jobs_file) do |f|
            begin
              Marshal.load(f)
            rescue
              nil
            end
          end
        end
      end

      def on_origen_shutdown(_options = {})
        save_remote_jobs if @remote_jobs
      end

      def save_remote_jobs
        File.open(remote_jobs_file, 'w') do |f|
          Marshal.dump(@remote_jobs, f)
        end
      end

      def execute_remotely(options = {})
        job_started(options[:id])
        begin
          if options[:dependents]
            wait_for_completion(ids:                      options[:dependents],
                                poll_duration_in_seconds: 1,
                                # Don't wait long by the time this runs the LSF
                                # should have guaranteed the job has run
                                timeout_in_seconds:       120
                               )
            unless options[:dependents].all? { |id| job_passed?(id) }
              File.open(log_file(options[:id]), 'w') do |f|
                f.puts "*** ERROR! *** #{options[:cmd].join(' ')} ***"
                f.puts 'Dependents failed!'
              end
              fail 'Dependents failed!'
            end
          end
          if options[:cmd].is_a?(Array)
            cmd = options[:cmd].join(' ')
          else
            cmd = options[:cmd]
          end
          output = `#{cmd} 2>&1`
          File.open(log_file(options[:id]), 'w') do |f|
            f.write output
          end
          if $CHILD_STATUS.success?
            job_passed(options[:id])
          else
            job_failed(options[:id])
          end
        rescue
          job_failed(options[:id])
        end
      end
    end
  end
end
