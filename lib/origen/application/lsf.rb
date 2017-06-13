module Origen
  class Application
    # Responsible for handling all submissions to the LSF
    class LSF
      include Origen::Utility::InputCapture
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

        def initialize
          @group = nil
          @project = 'msg.te'
          @debug = false

          # The following will grep the output of the bqueues command. It will search for the queue based on
          # the LSF configuration and assign the queue accordingly. This assumes that the queues are named short or shortq
          # and probably can be modified to parse out whatever we need as the queue name.
          # The resource is currently assigned as either linux or rhel6 as well dependent on the queue assignment
          `bqueues > /tmp/queuenames.log`
          file = File.open('/tmp/queuenames.log')
          columns = []
          file.each_line do |line|
            columns << line.split(' ')[0, 11]
          end
          queuenames = []
          # rubocop:disable Style/For: Prefer each over for
          for i in 1..(columns.size - 1)
            # rubocop:enable Style/For: Prefer each over for
            queuenames << columns[i][0]
          end
          if queuenames.include?('short')
            @queue = 'short'
            @resource = 'linux'
          elsif queuenames.include?('shortq')
            @queue = 'shortq'
            @resource = 'rhel6'
          end
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
          rerunnable = options[:rerunnable] ? '-r' : ''
          if options[:dependents].empty?
            dependents = ''
          else
            dependents = options[:dependents].map { |id| "ended(#{id})" }.join(' && ')
            dependents = "-w '#{dependents}'"
          end
          cmd = "bsub -oo /dev/null #{dependents} #{rerunnable} #{group} #{project} #{resource} #{queue} '#{command}'"
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
