require 'readline'
module Origen
  class VersionChecker
    include Origen::Utility::InputCapture

    def initialize(_options = {})
      @disable_origen_version_check = false
    end

    # Check that the required origen version dependency is satisfied, or else
    # update to it.
    #
    # This method will be disabled if version_check_disabled? returns true.
    def check!
      unless version_check_disabled?
        if Origen.config.required_origen_version
          if Origen.config.required_origen_version != Origen.version
            update_origen(Origen.config.required_origen_version)
          end
        else
          if Origen.config.min_required_origen_version
            if Origen.version.less_than?(Origen.config.min_required_origen_version) ||
               Origen.version.greater_than?(Origen.config.max_required_origen_version)
              update_origen(Origen.config.min_required_origen_version)
            end
          elsif Origen.config.max_required_origen_version
            fail "You can't specify a max_required_origen_version without providing a min_required_origen_version"
          end
        end
      end
    end

    # Returns true if the given condition is satisfied by the current Origen
    # version, examples of valid conditions are:
    #
    #   "v2.1.0"
    #   "v2.1.0.dev10"
    #   "> v2.1.0.dev10"
    #   ">= v2.1.0.dev10"
    def condition_satisfied?(condition, _options = {})
      Origen.version.condition_met?(condition)
    end

    # Disable all Origen version checks called from within the given block.
    # By default this will apply only to the current process, if :all_processes is
    # supplied and set to true then this will also apply to any additional
    # process threads started within the block.
    def with_disable_origen_version_check(options = {})
      if options[:all_processes]
        system "touch #{Origen.root}/.disable_origen_version_check"
      end
      @disable_origen_version_check = true
      begin
        yield
      ensure
        if options[:all_processes]
          system "rm -f #{Origen.root}/.disable_origen_version_check"
        end
        @disable_origen_version_check = false
      end
    end
    alias_method :disable_origen_version_check, :with_disable_origen_version_check

    # Returns true if version checking has been disabled or turned off
    # for a particular workspace.
    # Generally these are not things that an application can or should do, and are
    # more features to allow Origen to internally handle multi-application scenarios.
    def version_check_disabled?
      @disable_origen_version_check ||
        File.exist?("#{Origen.root}/.disable_origen_version_check")
    end

    # Check that the required origen version dependency is satisfied, or else
    # update to it.
    def update_origen(version, _options = {})
      puts ''
      puts 'Your Origen version needs to be changed, would you like this to be corrected automatically?'
      puts ''
      get_text(confirm: true, default: 'yes')

      ds = Origen::Utility::DesignSync.new
      mods = ds.modified_objects(Origen.top, rec: true, refresh: true)
      unless mods.empty?

        mods.map! do |local_path|
          p = Pathname.new("#{Origen.top}/#{local_path}")
          p.relative_path_from(Pathname.pwd)
        end

        puts 'Sorry but your environment has the following edits to Origen that are preventing automatic update:'
        puts ''
        mods.each do |file|
          puts '  ' + Origen.app.cm.diff_cmd + ' ' + file.to_s
        end
        puts ''

        abort <<-end_message
      If you don't care about these edits you can force un update now by running the following comand:

        dssc pop -rec -uni -force -ver #{version} #{Origen.top}

        end_message

      end

      ds.populate(Origen.top, version: version, rec: true, force: true,
                            unify: true, verbose: true, exclude: '.ref,.firmware',
                            incremental: true)

      puts ''
      puts 'Origen has been updated, please re-run your previous command.'
      puts ''

      exit 0
    end
  end
end
