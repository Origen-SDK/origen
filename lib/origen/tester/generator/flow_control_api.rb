module Origen
  module Tester
    module Generator
      module FlowControlAPI
        # Flow control methods related to flow context
        FLOW_METHODS = [
          # Methods in arrays are aliases, the primary name is the first one
          [:if_enable, :if_enabled, :enable, :enabled],
          [:unless_enable, :unless_enabled],
          [:if_job, :if_jobs],
          [:unless_job, :unless_jobs]
        ]

        # Flow control methods related to a relationship with another test
        RELATION_METHODS = [
          # Methods in arrays are aliases, the primary name is the first one
          :if_ran,
          :unless_ran,
          [:if_failed, :unless_passed],
          [:if_passed, :unless_failed],
          [:if_any_passed, :unless_all_failed],
          [:if_all_passed, :unless_any_failed],
          [:if_any_failed, :unless_all_passed],
          [:if_all_failed, :unless_any_passed]
        ]

        # Returns true if the test context generated from the supplied options + existing context
        # wrappers is different from that which was applied to the previous test.
        def context_changed?(options = {})
          current_context[:hash_code] != summarize_context(options)[:hash_code]
        end

        # @api private
        def save_context(options = {})
          # If the test has requested to use the current context...
          if options[:context] == :current
            replace_context_with_current(options)
          else
            @current_context = summarize_context(options)
            options.merge(@current_context[:context])
          end
        end

        # Returns a hash representing the current context, that is the context that was applied
        # to the last test.
        #
        # The hash contains two items:
        #
        # * :context contains a hash that summarises the flow control options that have been
        #   used, for example it may contain something like: :if_enable => "data_collection"
        # * :hash_code returns a hash-code for the values contained in the :context arrary. Any
        #   two equivalent contexts will have the same :hash_code, therefore this can be used
        #   to easily check the equivalence of any two contexts.
        def current_context
          @current_context ||= save_context
        end

        # @api private
        #
        # Removes any context options from the given options hash and merges in the current
        # context
        def replace_context_with_current(options)
          options = options.merge({})
          [FLOW_METHODS, RELATION_METHODS].flatten.each do |m|
            options.delete(m)
          end
          options.merge(current_context[:context])
        end

        # Returns a hash like that returned by current_context based on the given set of options +
        # existing context wrappers.
        def summarize_context(options = {})
          code = []
          context = {}
          (FLOW_METHODS + RELATION_METHODS).each do |m|
            primary = m.is_a?(Array) ? m.first : m
            val = false
            [m].flatten.each do |m|
              if options[m]
                val = options[m]
              elsif instance_variable_get("@#{m}_block")
                val = instance_variable_get("@#{m}_block")
              end
            end
            if val
              code << primary
              code << val
              context[primary] = val
            end
          end
          { hash_code: code.flatten.hash, context: context }
        end

        # All tests generated within the given block will be assigned the given enable word.
        #
        # If a test encountered within the block already has another enable word assigned to it then
        # an error will be raised.
        def if_enable(word, _options = {})
          @if_enable_block = word
          yield word
          @if_enable_block = nil
        end
        alias_method :if_enabled, :if_enable

        # All tests generated will not run unless the given enable word is asserted.
        def unless_enable(word, options = {})
          @unless_enable_block = word unless options[:or]
          yield word
          @unless_enable_block = nil
        end
        alias_method :unless_enabled, :unless_enable

        # All tests generated within the given block will be enabled only for the given jobs.
        def if_job(*jobs)
          jobs = jobs.flatten
          @if_job_block = @if_job_block ? @if_job_block + jobs : jobs
          yield
          @if_job_block = nil
        end
        alias_method :if_jobs, :if_job

        # All tests generated within the given block will be enabled only for the given jobs.
        def unless_job(*jobs)
          jobs = jobs.flatten
          @unless_job_block = @unless_job_block ? @unless_job_block + jobs : jobs
          yield
          @unless_job_block = nil
        end
        alias_method :unless_jobs, :unless_job

        # All tests generated within the given block will only run if the given test id has also
        # run earlier in the flow
        def if_ran(test_id, options = {})
          test_id = Origen.interface.filter_id(test_id, options)
          return if options.key?(:if) && !options[:if]
          return if options.key?(:unless) && options[:unless]
          if @if_ran_block
            fail 'Sorry but nesting of if_ran is not currently supported!'
          end
          @if_ran_block = test_id
          yield
          @if_ran_block = nil
        end

        # All tests generated within the given block will only run if the given test id has not
        # run earlier in the flow
        def unless_ran(test_id, options = {})
          test_id = Origen.interface.filter_id(test_id, options)
          return if options.key?(:if) && !options[:if]
          return if options.key?(:unless) && options[:unless]
          if @unless_ran_block
            fail 'Sorry but nesting of unless_ran is not currently supported!'
          end
          @unless_ran_block = test_id
          yield
          @unless_ran_block = nil
        end

        # All tests generated within the given block will only run if the given test id has
        # failed earlier in the flow
        def if_failed(test_id, options = {})
          test_id = Origen.interface.filter_id(test_id, options)
          return if options.key?(:if) && !options[:if]
          return if options.key?(:unless) && options[:unless]
          if @if_failed_block
            fail 'Sorry but nesting of if_failed is not currently supported!'
          end
          @if_failed_block = test_id
          yield
          @if_failed_block = nil
        end
        alias_method :unless_passed, :if_failed

        # All tests generated within the given block will only run if the given test id has
        # passed earlier in the flow
        def if_passed(test_id, options = {})
          test_id = Origen.interface.filter_id(test_id, options)
          return if options.key?(:if) && !options[:if]
          return if options.key?(:unless) && options[:unless]
          if @if_passed_block
            fail 'Sorry but nesting of if_passed is not currently supported!'
          end
          @if_passed_block = test_id
          yield
          @if_passed_block = nil
        end
        alias_method :unless_failed, :if_passed

        # All tests generated within the given block will only run if the given test id has
        # passed ON ANY SITE earlier in the flow
        def if_any_passed(test_id, options = {})
          test_id = Origen.interface.filter_id(test_id, options)
          return if conditionally_deactivated?(options)
          if @if_any_passed_block
            fail 'Sorry but nesting of if_any_passed is not currently supported!'
          end
          @if_any_passed_block = test_id
          yield
          @if_any_passed_block = nil
        end
        alias_method :unless_all_failed, :if_any_passed

        # All tests generated within the given block will only run if the given test id has
        # passed ON ALL SITES earlier in the flow
        def if_all_passed(test_id, options = {})
          test_id = Origen.interface.filter_id(test_id, options)
          return if conditionally_deactivated?(options)
          if @if_all_passed_block
            fail 'Sorry but nesting of if_all_passed is not currently supported!'
          end
          @if_all_passed_block = test_id
          yield
          @if_all_passed_block = nil
        end
        alias_method :unless_any_failed, :if_all_passed

        # All tests generated within the given block will only run if the given test id has
        # failed ON ANY SITE earlier in the flow
        def if_any_failed(test_id, options = {})
          test_id = Origen.interface.filter_id(test_id, options)
          return if conditionally_deactivated?(options)
          if @if_any_failed_block
            fail 'Sorry but nesting of if_any_failed is not currently supported!'
          end
          @if_any_failed_block = test_id
          yield
          @if_any_failed_block = nil
        end
        alias_method :unless_all_passed, :if_any_failed

        # All tests generated within the given block will only run if the given test id has
        # failed ON ALL SITES earlier in the flow
        def if_all_failed(test_id, options = {})
          test_id = Origen.interface.filter_id(test_id, options)
          return if conditionally_deactivated?(options)
          if @if_all_failed_block
            fail 'Sorry but nesting of if_all_failed is not currently supported!'
          end
          @if_all_failed_block = test_id
          yield
          @if_all_failed_block = nil
        end
        alias_method :unless_any_passed, :if_all_failed

        def conditionally_deactivated?(options)
          (options.key?(:if) && !options[:if]) ||
            (options.key?(:unless) && options[:unless])
        end

        def find_by_id(id, options = {}) # :nodoc:
          options = {
            search_other_flows: true
          }.merge(options)
          # Look within the current flow for a match first
          t = identity_map[id.to_sym]
          return t if t
          # If no match then look across other flow modules for a match
          # This currently returns the first match, should it raise an error on multiple?
          if options[:search_other_flows]
            Origen.interface.flow_generators.any? do |flow|
              t = flow.find_by_id(id, search_other_flows: false)
            end
          end
          t
        end

        def identity_map # :nodoc:
          @identity_map ||= {}
        end

        # If a class that includes this module has a finalize method it must
        # call apply_relationships
        def finalize(_options = {}) # :nodoc:
          apply_relationships
        end

        def apply_relationships # :nodoc:
          if @relationships
            @relationships.each do |rel|
              t = find_by_id(rel[:target_id])
              fail "Test not found with ID: #{rel[:target_id]}, referenced in flow: #{filename}" unless t
              t.id = rel[:target_id]
              confirm_valid_context(t, rel[:dependent])
              case rel[:type]
              # The first cases here contain J750 logic, these should be replaced
              # with the call method style used for the later cases when time permits.
              when :failed
                if rel[:dependent].respond_to?(:run_if_failed)
                  rel[:dependent].run_if_failed(rel[:target_id])
                else
                  t.continue_on_fail
                  flag = t.set_flag_on_fail
                  rel[:dependent].flag_true = flag
                end
              when :passed
                if rel[:dependent].respond_to?(:run_if_passed)
                  rel[:dependent].run_if_passed(rel[:target_id])
                else
                  t.continue_on_fail
                  flag = t.set_flag_on_pass
                  rel[:dependent].flag_true = flag
                end
              when :if_ran, :unless_ran
                if rel[:type] == :if_ran
                  if rel[:dependent].respond_to?(:run_if_ran)
                    rel[:dependent].run_if_ran(rel[:target_id])
                  else
                    # t.continue_on_fail
                    flag = t.set_flag_on_ran
                    rel[:dependent].flag_true = flag
                  end
                else
                  if rel[:dependent].respond_to?(:run_unless_ran)
                    rel[:dependent].run_unless_ran(rel[:target_id])
                  else
                    # t.continue_on_fail
                    flag = t.set_flag_on_ran
                    rel[:dependent].flag_clear = flag
                  end
                end
              when :any_passed
                rel[:dependent].run_if_any_passed(t)
              when :all_passed
                rel[:dependent].run_if_all_passed(t)
              when :any_failed
                rel[:dependent].run_if_any_failed(t)
              when :all_failed
                rel[:dependent].run_if_all_failed(t)
              else
                fail 'Unknown relationship type!'
              end
            end
            @relationships = nil
          end
        end

        def confirm_valid_context(_test, _dependent) # :nodoc:
          # TODO:  Add some validation checks here, for example make sure the dependent
          #        executes in the same job(s) as the test, otherwise the dependent will
          #        never be hit and will cause a validation error.
        end

        def record_id(test, options = {})
          if options[:id]
            @@existing_ids ||= []
            if @@existing_ids.include?(options[:id].to_sym)
              fail "The ID '#{test.id}' is not unique, it has already been assigned!"
            else
              @@existing_ids << options[:id].to_sym
            end
            identity_map[options[:id].to_sym] = test
          end
        end

        # @api private
        def at_run_start
          @@existing_ids = nil
          @@labels = nil
        end
        alias_method :reset_globals, :at_run_start

        # As generation of render and imports is not linear its possible that the test being
        # referenced does not exist in the collection yet.
        # Therefore the required relationship will be recorded for now and applied later upon
        # closing the generator at which point the complete final collection will be available.
        #
        # Note - as of v2.0.1.dev64 the above is no longer true - imports are generated linearly.
        # Therefore parent test should always already exist and it is possible that this relationship
        # handling could be cleaned up considerably.
        #
        # However we should keep it around for now as it may come in useful when other tester
        # platforms are supported in the future.
        def track_relationships(test_options = {}) # :nodoc:
          [:id, RELATION_METHODS].flatten.each do |id|
            if test_options[id]
              test_options[id] = Origen.interface.filter_id(test_options[id], test_options)
            end
          end
          options = extract_relation_options!(test_options)
          current_test = yield test_options
          record_id(current_test, test_options)
          @relationships ||= []
          target_id = options[:if_failed] || options[:unless_passed] || @if_failed_block
          if target_id
            @relationships << {
              type:      :failed,
              target_id: target_id,
              dependent: current_test
            }
          end
          target_id = options[:if_passed] || options[:unless_failed] || @if_passed_block
          if target_id
            @relationships << {
              type:      :passed,
              target_id: target_id,
              dependent: current_test
            }
          end
          target_id = options.delete(:if_ran) || @if_ran_block
          if target_id
            @relationships << {
              type:      :if_ran,
              target_id: target_id,
              dependent: current_test
            }
          end
          target_id = options.delete(:unless_ran) || @unless_ran_block
          if target_id
            @relationships << {
              type:      :unless_ran,
              target_id: target_id,
              dependent: current_test
            }
          end
          target_id = options[:if_any_passed] || options[:unless_all_failed] || @if_any_passed_block
          if target_id
            @relationships << {
              type:      :any_passed,
              target_id: target_id,
              dependent: current_test
            }
          end
          target_id = options[:if_all_passed] || options[:unless_any_failed] || @if_all_passed_block
          if target_id
            @relationships << {
              type:      :all_passed,
              target_id: target_id,
              dependent: current_test
            }
          end
          target_id = options[:if_any_failed] || options[:unless_all_passed] || @if_any_failed_block
          if target_id
            @relationships << {
              type:      :any_failed,
              target_id: target_id,
              dependent: current_test
            }
          end
          target_id = options[:if_all_failed] || options[:unless_any_passed] || @if_all_failed_block
          if target_id
            @relationships << {
              type:      :all_failed,
              target_id: target_id,
              dependent: current_test
            }
          end
          if test_options[:context] == :current  # Context has already been applied
            current_test
          else
            apply_current_context!(current_test)
          end
        end

        def apply_current_context!(line) # :nodoc:
          if @if_enable_block
            if line.enable && line.enable != @if_enable_block
              fail "Cannot apply enable word '#{@if_enable_block}' to '#{line.parameter}', it already has '#{line.enable}'"
            else
              line.enable = @if_enable_block
            end
          end
          if @unless_enable_block
            line.unless_enable = @unless_enable_block
          end
          line.if_job = @if_job_block if @if_job_block
          line.unless_job = @unless_job_block if @unless_job_block
          line
        end

        # Removes any flow relationship options from given hash and returns them
        # in a new hash
        def extract_relation_options!(options) # :nodoc:
          opts = {}
          RELATION_METHODS.flatten.each do |o|
            opts[o] = options.delete(o)
          end
          opts
        end

        def extract_flow_control_options!(options)
          opts = {}
          FLOW_METHODS.flatten.each do |o|
            if options.key?(o)
              opts[o] = options.delete(o)
            end
          end
          opts
        end

        def generate_unique_label(id = nil)
          id = 'label' if !id || id == ''
          label = "#{Origen.interface.app_identifier}_#{id}"
          label.gsub!(' ', '_')
          label.upcase!
          @@labels ||= {}
          @@labels[Origen.tester.class] ||= {}
          @@labels[Origen.tester.class][label] ||= 0
          @@labels[Origen.tester.class][label] += 1
          "#{label}_#{@@labels[Origen.tester.class][label]}"
        end

        module Interface
          # Implement this method in your application interface if you want to
          # sanitize all ID references used in the flow control API.
          # For example you could use this to append a flow name prefix to every
          # ID reference within a flow which can help with ID duplication problems
          # when flow snippets are re-used.
          def filter_id(id, _options = {})
            id
          end

          def extract_relation_options!(*args)
            flow.extract_relation_options!(*args)
          end

          def extract_flow_control_options!(*args)
            flow.extract_flow_control_options!(*args)
          end

          # Alias for flow#if_enable
          def if_enable(*args, &block)
            flow.if_enable(*args, &block)
          end
          alias_method :if_enabled, :if_enable

          # Alias for flow#unless_enable
          def unless_enable(*args, &block)
            flow.unless_enable(*args, &block)
          end
          alias_method :unless_enabled, :unless_enable

          # Alias for flow#if_job
          def if_job(*args, &block)
            flow.if_job(*args, &block)
          end

          # Alias for flow#unless_job
          def unless_job(*args, &block)
            flow.unless_job(*args, &block)
          end

          # Alias for flow#unless_ran
          def unless_ran(*args, &block)
            flow.unless_ran(*args, &block)
          end

          # Alias for flow#if_ran
          def if_ran(*args, &block)
            flow.if_ran(*args, &block)
          end

          # Alias for flow#if_failed
          def if_failed(*args, &block)
            flow.if_failed(*args, &block)
          end
          alias_method :unless_passed, :if_failed

          # Alias for flow#if_passed
          def if_passed(*args, &block)
            flow.if_passed(*args, &block)
          end
          alias_method :unless_failed, :if_passed

          # Alias for flow#if_any_passed
          def if_any_passed(*args, &block)
            flow.if_any_passed(*args, &block)
          end
          alias_method :unless_all_failed, :if_any_passed

          # Alias for flow#if_all_passed
          def if_all_passed(*args, &block)
            flow.if_all_passed(*args, &block)
          end
          alias_method :unless_any_failed, :if_all_passed

          # Alias for flow#if_any_failed
          def if_any_failed(*args, &block)
            flow.if_any_failed(*args, &block)
          end
          alias_method :unless_all_passed, :if_any_failed

          # Alias for flow#if_all_failed
          def if_all_failed(*args, &block)
            flow.if_all_failed(*args, &block)
          end
          alias_method :unless_any_passed, :if_all_failed

          # Alias for flow#skip
          def skip(*args, &block)
            flow.skip(*args, &block)
          end

          # Alias for flow#current_context
          def current_context(*args, &block)
            flow.current_context(*args, &block)
          end

          # Alias for flow#context_changed?
          def context_changed?(*args, &block)
            flow.context_changed?(*args, &block)
          end
        end
      end
    end
  end
end
