module Origen
  module Tester
    class J750
      module Generator
        class Flow
          include Origen::Tester::Generator
          include Origen::Tester::Generator::FlowControlAPI

          TEMPLATE = "#{Origen.top}/lib/origen/tester/j750/generator/templates/flow.txt.erb"
          OUTPUT_POSTFIX = 'flow'

          def add(type, options = {})
            ins = false
            options = save_context(options) if [:test, :cz].include?(type)
            branch_unless_enabled(options) do |options|
              ins = track_relationships(options) do |options|
                FlowLine.new(type, options)
              end
              collection << ins unless Origen.interface.resources_mode?
              if ins.test?
                c = Origen.interface.consume_comments
                unless Origen.interface.resources_mode?
                  Origen.interface.descriptions.add_for_test_usage(ins.parameter, Origen.interface.top_level_flow, c)
                end
              else
                Origen.interface.discard_comments
              end
            end
            ins
          end

          def logprint(message, options = {})
            message.gsub!(/\s/, '_')
            add(:logprint, options.merge(parameter: message))
          end

          def test(instance, options = {})
            add(:test, options.merge(parameter: instance))
          end

          def cz(instance, cz_setup, options = {})
            add(:cz, options.merge(parameter: instance, cz_setup: cz_setup))
          end

          def goto(label, options = {})
            add(:goto, options.merge(parameter: label))
          end

          def nop(options = {})
            add(:nop, options.merge(parameter: nil))
          end

          def set_device(options = {})
            add(:set_device, options)
          end

          def set_error_bin(options = {})
            add(:set_error_bin, options)
          end

          def enable_flow_word(word, options = {})
            add(:enable_flow_word, options.merge(parameter: word))
          end

          def disable_flow_word(word, options = {})
            add(:disable_flow_word, options.merge(parameter: word))
          end

          # All tests generated will not run unless the given enable word is asserted.
          #
          # This is specially implemented for J750 since it does not have a native
          # support for flow word not enabled.
          # It will generate a goto branch around the tests contained with the block
          # if the given flow word is enabled.
          def unless_enable(word, options = {})
            if options[:or]
              yield
            else
              @unless_enable_block = word
              options = options.merge(unless_enable: word)
              branch_unless_enabled(options.merge(_force_unless_enable: true)) do
                yield
              end
              @unless_enable_block = nil
            end
          end
          alias_method :unless_enabled, :unless_enable

          def start_flow_branch(identifier, options = {})
            goto(identifier, options)
          end

          def skip(identifier = nil, options = {})
            identifier, options = nil, identifier if identifier.is_a?(Hash)
            identifier = generate_unique_label(identifier)
            goto(identifier, options)
            yield
            nop(label: identifier)
          end

          private

          # If the test has an unless_enable then branch around it
          def branch_unless_enabled(options)
            word = options.delete(:unless_enable) || options.delete(:unless_enabled)
            if word && (word != @unless_enable_block || options.delete(:_force_unless_enable))
              # Not sure if this is really required, but duplicating these hashes here to ensure
              # that all other flow context keys are preserved and applied to the branch lines
              orig_options = options.merge({})
              close_options = options.merge({})
              label = generate_unique_label
              goto(label, options.merge(if_enable: word))
              yield orig_options
              nop(close_options.merge(label: label))
            else
              yield options
            end
          end
        end
      end
    end
  end
end
