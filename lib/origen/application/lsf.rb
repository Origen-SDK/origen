module Origen
  class Application
    # Responsible for handling all submissions to the LSF
    class LSF
      # The LSF command configuration that will be used for all submissions to
      # the LSF. An instance of this class is returned via the configuration
      # method and which can be used to modify the LSF behavior on a per-setup
      # basis.
      class Configuration
        # The group parameter, default: nil
        attr_accessor :group
        # The project parameter, default: 'msg.te'
        attr_accessor :project
        # The resource parameter, default: 'linux'
        attr_accessor :resource
        # The queue parameter, default: 'short'
        attr_accessor :queue
        # When set to true no submissions will be made to LSF and instead the
        # command that would have been submitted is printed to the terminal instead
        attr_accessor :debug
        # Specify the number of cores to use while submitting the job to LSF
        # There is a restriction on the number of cores available per queue name
        # Below is a table:
        #         Queue name	      equivalent		Purpose
        #         interq	          gui			Interactive jobs, like Virtuoso. Max 15 jobs/user
        #         batchq	          normal		CPU intensive batch jobs, 1 .. 3 threads. Specify # of threads with bsub -n option. Slots/user: ~10% of total batch capacity.
        #         batchq_mt	          normal		CPU intensive batch jobs, >= 4 threads. Specify # of threads with bsub -n option. Slots: shared with batchq.
        #         shortq	          short			CPU intensive batch jobs, 1 thread (= 1 core), guaranteed run time 15 minutes. Slots/user: approximately 3x limit in batchq.
        #         offloadq	            -			Used for offloading cpu intensive batch jobs to cloud, see CloudPortal.
        #                                       		Do not submit directly into this queue. No real slot limit. Focused on CPU intensive jobs, not using much memory/data.
        #         distributed	          normal		Run jobs than span multiple hosts.
        #         -			  prio	                High prio queue with low slot count, useful if you don't have slots available in normal queue. See PrioritizingMyJobs.
        #         -			  ondemand     		On-Demand Servers to satisfy urgent and short-term (2 weeks or less) customer compute requirements.
        #         -			  wam	  		WAM cron processing
        #         -			  grid	     		Low-priority batch jobs (random sim, regressions, etc). Access to all spare CPU cycles.
        attr_accessor :cores

        def initialize
          @group = nil
          @project = 'msg.te'
          @resource = 'linux'
          @queue = 'short'
          @debug = false
          @cores = '1'
        end
      end

      # Accessor for the global LSF configuration, use this to modify the default
      # LSF configuration for a given setup. Typically an alternate configuration would
      # be added to the SoC class or the target file, but it can be set from anywhere.
      # This method returns an instance of Origen::Application::LSF::Configuration and can
      # be used as shown in the example.
      #
      # Example
      #   # soc/nevis.rb
      #
      #   Origen::Runner::LSF.configuration do |config|
      #     # Use "msg.nevis" for the project string when running in Noida
      #     if %x["domainname"] =~ /nidc/
      #       config.lsf.project =  "msg.nevis"
      #     end
      #   end
      #
      #   # Change the default group
      #   Origen.config.lsf.group = "lam"
      def self.configuration
        @config ||= Configuration.new
        yield @config if block_given?
        @config
      end

      # Returns the configuration for a given LSF instance, which always maps to the
      # global configuration instance.
      def configuration
        self.class.configuration
      end
      alias_method :config, :configuration

      # Submits the given command to the LSF, returns the LSF job ID
      def submit(command, options = {})
        options = {
          dependents: [],
          rerunnable: true,  # Will rerun automatically if the execution host fails
        }.merge(options)
        limit_job_submissions do
          group = options[:group] || config.group
          group = group ? "-G #{group}" : ''
          project = options[:project] || config.project
          project = project ? "-P #{project}" : ''
          resource = options[:resource] || config.resource
          resource = resource ? "-R '#{resource}'" : ''
          queue = options[:queue] || config.queue
          queue = queue ? "-q #{queue}" : ''
          cores = options[:cores] || config.cores
          cores = cores ? "-n #{cores}" : ''
          rerunnable = options[:rerunnable] ? '-r' : ''
          if options[:dependents].empty?
            dependents = ''
          else
            dependents = options[:dependents].map { |id| "ended(#{id})" }.join(' && ')
            dependents = "-w '#{dependents}'"
          end
          cmd = "bsub -oo /dev/null #{dependents} #{rerunnable} #{group} #{project} #{resource} #{queue} #{cores} '#{command}'"
          if config.debug
            puts cmd
            '496212'  # Return a dummy ID to keep the caller happy
          else
            output = `#{cmd}`
            Origen.log.info output.strip
            if output.split("\n").last =~ /Job <(\d+)> is submitted/
              Regexp.last_match[1]
            else
              :error
            end
          end
        end
      end

      def queuing_job_ids
        ids = []
        `bjobs 2>&1`.split("\n").each do |line|
          if line =~ /^(\d+).*PEND/
            ids << Regexp.last_match[1]
          end
        end
        ids
      end

      def running_job_ids
        ids = []
        `bjobs 2>&1`.split("\n").each do |line|
          if line =~ /^(\d+).*RUN/
            ids << Regexp.last_match[1]
          end
        end
        ids
      end

      def remote_jobs_count
        i = 0
        `bjobs 2>&1`.split("\n").each do |line|
          if line =~ /^(\d+).*(RUN|PEND)/
            i += 1
          end
        end
        i
      end

      # Limits the number of jobs submitted to the LSF at one time, IT will start
      # to warn if a single users current job count gets above 500.
      # This method prevents that stage from being reached.
      def limit_job_submissions
        @local_job_count ||= 0
        if @local_job_count == 100
          while remote_jobs_count > 400
            puts 'Waiting for submitted jobs count to fall below limit...'
            sleep 5
          end
          @local_job_count = 0
          yield
        else
          @local_job_count += 1
          yield
        end
      end
    end
  end
end
