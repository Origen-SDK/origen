require 'readline'
module RGen
  class VersionChecker
    include RGen::Utility::InputCapture

    def initialize(_options = {})
      @disable_rgen_version_check = false
    end

    # Check that the required rgen version dependency is satisfied, or else
    # update to it.
    #
    # This method will be disabled if version_check_disabled? returns true.
    def check!
      unless version_check_disabled?
        if RGen.config.required_rgen_version
          if RGen.config.required_rgen_version != RGen.version
            update_rgen(RGen.config.required_rgen_version)
          end
        else
          if RGen.config.min_required_rgen_version
            if RGen.version.less_than?(RGen.config.min_required_rgen_version) ||
               RGen.version.greater_than?(RGen.config.max_required_rgen_version)
              update_rgen(RGen.config.min_required_rgen_version)
            end
          elsif RGen.config.max_required_rgen_version
            fail "You can't specify a max_required_rgen_version without providing a min_required_rgen_version"
          end
        end
      end
    end

    # Returns true if the given condition is satisfied by the current RGen
    # version, examples of valid conditions are:
    #
    #   "v2.1.0"
    #   "v2.1.0.dev10"
    #   "> v2.1.0.dev10"
    #   ">= v2.1.0.dev10"
    def condition_satisfied?(condition, _options = {})
      RGen.version.condition_met?(condition)
    end

    # Disable all RGen version checks called from within the given block.
    # By default this will apply only to the current process, if :all_processes is
    # supplied and set to true then this will also apply to any additional
    # process threads started within the block.
    def with_disable_rgen_version_check(options = {})
      if options[:all_processes]
        system "touch #{RGen.root}/.disable_rgen_version_check"
      end
      @disable_rgen_version_check = true
      begin
        yield
      ensure
        if options[:all_processes]
          system "rm -f #{RGen.root}/.disable_rgen_version_check"
        end
        @disable_rgen_version_check = false
      end
    end
    alias_method :disable_rgen_version_check, :with_disable_rgen_version_check

    # Returns true if version checking has been disabled or turned off
    # for a particular workspace.
    # Generally these are not things that an application can or should do, and are
    # more features to allow RGen to internally handle multi-application scenarios.
    def version_check_disabled?
      @disable_rgen_version_check ||
        File.exist?("#{RGen.root}/.disable_rgen_version_check")
    end

    # Check that the required rgen version dependency is satisfied, or else
    # update to it.
    def update_rgen(version, _options = {})
      puts ''
      puts 'Your RGen version needs to be changed, would you like this to be corrected automatically?'
      puts ''
      get_text(confirm: true, default: 'yes')

      ds = RGen::Utility::DesignSync.new
      mods = ds.modified_objects(RGen.top, rec: true, refresh: true)
      unless mods.empty?

        mods.map! do |local_path|
          p = Pathname.new("#{RGen.top}/#{local_path}")
          p.relative_path_from(Pathname.pwd)
        end

        puts 'Sorry but your environment has the following edits to RGen that are preventing automatic update:'
        puts ''
        mods.each do |file|
          puts '  ' + RGen.app.cm.diff_cmd + ' ' + file.to_s
        end
        puts ''

        abort <<-end_message
      If you don't care about these edits you can force un update now by running the following comand:

        dssc pop -rec -uni -force -ver #{version} #{RGen.top}

        end_message

      end

      ds.populate(RGen.top, version: version, rec: true, force: true,
                            unify: true, verbose: true, exclude: '.ref,.firmware',
                            incremental: true)

      puts ''
      puts 'RGen has been updated, please re-run your previous command.'
      puts ''

      exit 0
    end
  end
end
