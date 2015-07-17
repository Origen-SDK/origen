require 'bundler'
module Origen
  # Supports executing code regression testing.
  #
  # Reference workspace used for comparison will automatically be
  # populated based on tag selected (default: latest).
  #
  # An instance of this class is hooked up to:
  #     Origen.regression_manager
  # == Basic Usage
  #   options[:target] = %w{target1.rb target2.rb target3.rb}
  #   Origen.regression_manager.run(options) do |options|
  #     Origen.target.loop(options) do |options|
  #       Origen.lsf.submit_origen_job "generate regression.list -t #{options[:target]}"
  #     end
  #   end
  class RegressionManager
    include Utility::InputCapture
    include Users

    def ws
      Origen.app.workspace_manager
    end

    # Serves to execute a regression.
    # Any block of code passed to this method will receive regression check
    # @param [Hash] options Options to customize the run instance
    # @option options [Array]   :target String Array of target names on which to run regression
    # @option options [Boolean] :build_reference (true) Build reference workspace automatically
    # @option options [Boolean] :send_email (false) Send results email when regression complete
    # @option options [Boolean] :email_all_developers (false) If sending email, whether to email all developers or just user
    # @option options [Boolean] :report_results (false) Whether to report results inline to console
    #
    #
    def run(options = {})
      options = {
        build_reference:      true,
        send_email:           false,
        email_all_developers: false,
        report_results:       false,
        uses_lsf:             true
      }.merge(options)
      options = load_options if running_in_reference_workspace?
      targets = prepare_targets(options)
      if running_in_reference_workspace?
        Origen.lsf.clear_all
        yield options
        wait_for_completion(options) if options[:uses_lsf]
        save_and_delete_output
      else
        if options[:build_reference]
          @reference_tag = version_to_tag(options[:version] || get_version(options))
          setup_reference_workspace
          # Generate the reference files
          save_options(options)
          Origen.with_origen_root(reference_origen_root) do
            Origen.with_disable_origen_version_check(all_processes: true) do
              Dir.chdir reference_origen_root do
                Bundler.with_clean_env do
                  system 'origen -v'  # Used to make sure gems install
                  Origen.log.info '######################################################'
                  Origen.log.info 'running regression command in reference workspace...'
                  Origen.log.info '######################################################'
                  Origen.log.info
                  system 'origen regression'
                end
              end
            end
          end
        end
        # Generate the latest files for comparison
        Origen.lsf.clear_all
        Origen.log.info '######################################################'
        Origen.log.info 'running regression command in local workspace...'
        Origen.log.info '######################################################'
        Origen.log.info
        yield options
        wait_for_completion(options) if options[:uses_lsf]
        summarize_results(options)
      end
    end

    def summarize_results(options = {})
      Origen.lsf.build_log
      stats = Origen.app.stats
      if options[:report_results]
        puts "Regression results: \n"
        puts "#{stats.summary_text}\n"
      end
      if stats.clean_run?
        stats.report_pass
      else
        stats.report_fail
      end
      if options[:send_email]
        to = options[:email_all_developers] ? developers : current_user
        Origen.mailer.send_regression_complete_notice(to: to)
      end
    end

    # Saves all generated output (to the reference dir) and then
    # deletes the output directory to save space
    def save_and_delete_output
      Origen.lsf.build_log
      Origen.log.flush
      Dir.chdir reference_origen_root do
        Bundler.with_clean_env do
          system 'origen save all'
        end
      end
      FileUtils.rm_rf "#{reference_origen_root}/output"
    end

    # Cycle through all targets in the upcoming run to ensure
    # that all output directories exist
    def prepare_targets(options)
      targets = [options[:target], options[:targets]].flatten.compact
      if targets.empty?
        puts 'You must supply the targets you are going to run in the options'
        puts 'passed to regression_manager.run.'
        fail
      end
      Origen.target.loop(options) { |_options| }
      targets
    end

    def store_file
      @store_file ||= Pathname.new "#{reference_origen_root}/.regression_options"
    end

    def load_options
      options = {}
      if File.exist?(store_file)
        File.open(store_file.to_s) do |f|
          options = Marshal.load(f)
        end
        FileUtils.rm_f store_file
      end
      options
    end

    def save_options(options)
      File.open(store_file.to_s, 'w') do |f|
        Marshal.dump(options, f)
      end
    end

    def running_in_reference_workspace?
      File.exist?("#{Origen.root}/.this_is_a_reference_workspace")
    end

    def wait_for_completion(_options = {})
      highlight { Origen.log.info 'Waiting for all to complete...' }
      Origen.lsf.wait_for_completion
    end

    def reference_origen_root
      if running_in_reference_workspace?
        Origen.root
      else
        ws.origen_root(@reference_workspace)
      end
    end

    def setup_reference_workspace
      if ws.reference_workspace_set?
        @reference_workspace = ws.reference_workspace
      else
        @reference_workspace = get_reference_workspace
        unless File.exist?(@reference_workspace)
          highlight { Origen.log.info 'Building reference workspace...' }
          ws.build(@reference_workspace)
        end
        ws.set_reference_workspace(@reference_workspace)
      end
      highlight { Origen.log.info "Switching reference workspace to version #{@reference_tag}..." }
      ws.switch_version(@reference_workspace, @reference_tag, origen_root_only: true)
      unless File.exist?("#{reference_origen_root}/.this_is_a_reference_workspace")
        system "touch #{reference_origen_root}/.this_is_a_reference_workspace"
      end
      copy_regression_file
    end

    # We want the reference workspace to run the same regression as the local
    # workspace, so copy the current version of the regression command file
    # across.
    def copy_regression_file
      path_to_command_file = regression_command_file.relative_path_from(Origen.root)
      system "rm -f #{reference_origen_root}/#{path_to_command_file}"
      system "cp #{Origen.root}/#{path_to_command_file} #{reference_origen_root}/#{path_to_command_file}"
    end

    # Returns a full path to the regression command file within the local application
    def regression_command_file
      first_call = caller.find { |line| line =~ /regression_manager.rb.*run/ }
      app_caller_line = caller[caller.index(first_call) + 1]
      app_caller_line =~ /(.*\.rb)/
      path = Pathname.new(Regexp.last_match[1])
    end

    def get_reference_workspace(_options = {})
      puts ''
      puts 'It looks like this is the first time that you have run a regression from this workspace.'
      puts ''
      puts 'In order to run a regression test Origen must have access to a secondary workspace in which'
      puts 'it can build the reference files.'
      puts ''
      puts 'Generally all of your developments workspaces should use the same reference workspace.'
      puts ''
      puts 'Origen will make a suggestion for the reference workspace below, however if you know that'
      puts 'you already have an existing one at a different location then please enter the path.'
      puts ''
      puts 'WHERE SHOULD THE REFERENCE WORKSPACE RESIDE?'
      puts ''
      get_text(default: ws.reference_workspace_proposal, single: true)
    end

    def get_version(_options = {})
      puts ''
      puts 'WHAT VERSION DO YOU WANT TO COMPARE AGAINST?'
      puts ''
      if Origen.app.rc.git?
        puts "Valid values are 'latest', 'last' (production release), a tag, a commit or a branch."
      else
        puts "Valid values are 'latest', 'last' (production release), or a tag."
      end
      puts ''
      get_text(default: Origen.app.version, single: true)
    end

    def version_to_tag(version)
      version = version.strip
      if version.downcase == 'last'
        Origen.app.version_tracker.versions.last
      elsif version.downcase == 'latest'
        version
      else
        version
      end
    end

    private

    def highlight
      Origen.log.info ''
      Origen.log.info '######################################################################'
      yield
      Origen.log.info '######################################################################'
      Origen.log.info ''
    end
  end
end
