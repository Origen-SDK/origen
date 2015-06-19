module RGen
  class Application
    class Configuration
      require 'pathname'

      # Returns the configuration's application instance
      attr_reader :app

      attr_accessor :name, :initials, :instructions, :required_rgen_version,
                    :min_required_rgen_version, :max_required_rgen_version,
                    :history_file, :release_directory, :release_email_subject,
                    :production_targets, :mode,
                    :vault, :output_directory, :reference_directory,
                    :semantically_version, :log_directory, :pattern_name_translator,
                    :pattern_directory, :pattern_output_directory, :pattern_prefix, :pattern_postfix,
                    :pattern_header, :default_lsf_action, :release_instructions, :proceed_with_pattern,
                    :test_program_output_directory, :erb_trim_mode, :test_program_source_directory,
                    :test_program_template_directory, :referenced_pattern_list, :program_prefix,
                    :copy_command, :diff_command, :compile_only_dot_erb_files, :web_directory,
                    :web_domain, :snapshots_directory, :imports, :imports_dev,
                    :strict_errors, :unmanaged_dirs, :unmanaged_files, :remotes,
                    :external_app_dirs, :lint_test, :shared, :yammer_group, :rc_url, :rc_workflow,
                    :user_aliases

      # Mark any attributes that are likely to depend on properties of the target here,
      # this will raise an error if they are ever accessed before the target has been
      # instantiated (a concern for RGen core developers only).
      #
      # These attributes will also receive an enhanced accessor that accepts a block, see
      # below for more details on this.
      ATTRS_THAT_DEPEND_ON_TARGET = [
        :output_directory, :reference_directory, :pattern_postfix, :pattern_prefix,
        :pattern_header, :release_directory, :pattern_name_translator, :pattern_directory, :pattern_output_directory,
        :proceed_with_pattern, :test_program_output_directory, :test_program_source_directory,
        :test_program_template_directory, :referenced_pattern_list, :program_prefix, :web_directory,
        :web_domain
      ]

      # Any attributes that want to accept a block, but not necessarily require the target
      # can be added here
      ATTRS_THAT_ACCEPT_A_BLOCK = ATTRS_THAT_DEPEND_ON_TARGET +
                                  [:release_instructions, :history_file, :log_directory, :copy_command,
                                   :diff_command, :snapshots_directory, :imports, :imports_dev, :remotes,
                                   :external_app_dirs
                                  ]

      # If a current plugin is present then its value for these attributes will be
      # used instead of that from the current application
      ATTRS_THAT_CURRENT_PLUGIN_CAN_OVERRIDE = [
        :pattern_prefix, :pattern_postfix, :program_prefix, :pattern_header, :pattern_output_directory,
        :output_directory, :reference_directory, :test_program_output_directory,
        :test_program_template_directory, :referenced_pattern_list
      ]

      def log_deprecations
        unless imports.empty?
          RGen.deprecate "App #{app.name} uses config.imports this will be removed in RGen V3 and a Gemfile/.gemspec should be used instead"
        end
        unless imports_dev.empty?
          RGen.deprecate "App #{app.name} uses config.imports_dev this will be removed in RGen V3 and a Gemfile/.gemspec should be used instead"
        end
        if required_rgen_version
          RGen.deprecate "App #{app.name} uses config.required_rgen_version this will be removed in RGen V3 and a Gemfile/.gemspec should be used instead"
        end
        if min_required_rgen_version
          RGen.deprecate "App #{app.name} uses config.min_required_rgen_version this will be removed in RGen V3 and a Gemfile/.gemspec should be used instead"
        end
        if max_required_rgen_version
          RGen.deprecate "App #{app.name} uses config.max_required_rgen_version this will be removed in RGen V3 and a Gemfile/.gemspec should be used instead"
        end
      end

      def initialize(app)
        @app = app
        @mode = RGen::Mode.new
        @name = 'Unknown'
        @initials = 'NA'
        @semantically_version = false
        @compile_only_dot_erb_files = true
        # Functions used here since RGen.root is not available when this is first instantiated
        @output_directory = -> { "#{RGen.root}/output" }
        @reference_directory = -> { "#{RGen.root}/.ref" }
        @release_directory = -> { RGen.root }
        @release_email_subject = false
        @log_directory = -> { "#{RGen.root}/log" }
        @pattern_name_translator = ->(name) { name }
        @pattern_directory = -> { "#{RGen.root}/pattern" }
        @pattern_output_directory = -> { "#{RGen.root}/output/patterns" }
        @history_file = -> { "#{RGen.root}/doc/history" }
        @default_lsf_action = :clear
        @proceed_with_pattern = ->(_name) { true }
        @erb_trim_mode = '%'
        @referenced_pattern_list = -> { "#{RGen.root}/list/referenced.list" }
        @copy_command = -> { RGen.running_on_windows? ? 'copy' : 'cp' }
        @diff_command = -> { RGen.running_on_windows? ? 'start winmerge' : 'tkdiff' }
        @imports = []
        @imports_dev = []
        @external_app_dirs = []
        @unmanaged_dirs = []
        @unmanaged_files = []
        @remotes = []
        @lint_test = {}
        @user_aliases = {}
      end

      # This defines an enhanced accessor for these attributes that allows them to be assigned
      # to an annonymous function to calculate the value based on some property of the target
      # objects.
      #
      # Without this the objects frome the target could not be referenced in config/application.rb
      # because they don't exist yet, for example this will not work because $dut has not yet
      # been instantiated:
      #   # config/application.rb
      #
      #   config.output_directory = "#{RGen.root}/output/#{$dut.class}"
      #
      # However this accessor provides a way to do that via the following syntax:
      #   # config/application.rb
      #
      #   config.output_directory do
      #     "#{RGen.root}/output/#{$dut.class}"
      #   end
      #
      # Or on one line:
      #   # config/application.rb
      #
      #   config.output_directory { "#{RGen.root}/output/#{$dut.class}" }
      #
      # Or if you prefer the more explicit:
      #   # config/application.rb
      #
      #   config.output_directory = ->{ "#{RGen.root}/output/#{$dut.class}" }
      ATTRS_THAT_ACCEPT_A_BLOCK.each do |name|
        define_method name do |override = true, &block|
          if block # _given?
            instance_variable_set("@#{name}".to_sym, block)
          else
            if override && ATTRS_THAT_CURRENT_PLUGIN_CAN_OVERRIDE.include?(name) &&
               app.current? && RGen.current_plugin.name
              var = RGen.current_plugin.instance.config.send(name, override: false)
            end
            var ||= instance_variable_get("@#{name}".to_sym)
            if var.respond_to?('call')
              if ATTRS_THAT_DEPEND_ON_TARGET.include?(name)
                # If an attempt has been made to access this attribute before the target has
                # been instantiated raise an error
                # Note RGen.app here instead of just app to ensure we are talking to the top level application,
                # that is the only one that has a target
                unless RGen.app.target_instantiated?
                  fail "You have attempted to access RGen.config.#{name} before instantiating the target"
                end
              end
              var.call
            else
              var
            end
          end
        end
      end

      (ATTRS_THAT_CURRENT_PLUGIN_CAN_OVERRIDE - ATTRS_THAT_ACCEPT_A_BLOCK).each do |name|
        if override && ATTRS_THAT_CURRENT_PLUGIN_CAN_OVERRIDE.include?(name) &&
           app.current? && RGen.current_plugin.name
          var = RGen.current_plugin.instance.config.send(name, override: false)
        end
        var || instance_variable_get("@#{name}".to_sym)
      end

      def pattern_name_translator(name = nil, &block)
        if block
          @pattern_name_translator = block
        else
          @pattern_name_translator.call(name)
        end
      end

      def proceed_with_pattern(name = nil, &block)
        if block
          @proceed_with_pattern = block
        else
          @proceed_with_pattern.call(name)
        end
      end

      # Add a new pattern iterator
      def pattern_iterator
        yield RGen.generator.create_iterator
      end

      def mode=(val)
        @mode.set(val)
      end

      def lsf
        app.lsf.configuration
      end

      # Prevent a new attribute from a future version of RGen from dying before the
      # user can be prompted to upgrade
      def method_missing(method, *_args, &_block)
        method = method.to_s.sub('=', '')
        puts "WARNING - unknown configuration attribute: #{method}"
      end
    end
  end
end
