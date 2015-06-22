module Origen
  module Tester
    class V93K
      module Generator
        class Flow
          include Origen::Tester::Generator

          attr_accessor :test_functions, :test_suites, :test_methods

          TEMPLATE = "#{Origen.top}/lib/origen/tester/v93k/generator/templates/template.flow.erb"

          def filename
            super.gsub('_flow', '')
          end

          def run(test_suite, options = {})
            add(:run, { test_suite: test_suite }.merge(options))
          end

          def run_and_branch(test_suite, options = {})
            add(:run_and_branch, { test_suite: test_suite }.merge(options))
          end

          private

          def add(type, options = {})
            options = update_relationships(options)
            ins = FlowLine.new(type, options)
            collection << ins
            if ins.test?
              c = Origen.interface.consume_comments
              Origen.interface.descriptions.add_for_test_usage(ins.parameter, Origen.interface.top_level_flow, c)
            else
              Origen.interface.discard_comments
            end
            ins
          end

          def update_relationships(options = {})
            fail_id = options.delete(:if_failed)
            pass_id = options.delete(:if_passed)
            if fail_id
              t = find_by_id(fail_id)
              t.continue_on_fail
              flag = t.set_flag_on_fail
              options[:flag_true] = flag
            elsif pass_id
              t = find_by_id(pass_id)
              t.continue_on_fail
              flag = t.set_flag_on_pass
              options[:flag_true] = flag
            end
            options
          end

          def find_by_id(id)
            collection.find { |l| l.id == id }
          end
        end
      end
    end
  end
end
