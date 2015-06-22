module Origen
  module Tester
    class V93K
      module Generator
        class TestSuites
          # Origen::Tester::Generator not included since test suites do not have their
          # own top-level sheet, they will be incorporated within the flow sheet

          attr_accessor :flow, :collection

          def initialize(flow)
            @flow = flow
            @collection = []
          end

          def filename
            flow.filename
          end

          def add(name, options = {})
            check_for_duplicates(name)
            record_test_suite(name)
            suite = TestSuite.new(name, options)
            @collection << suite
            # c = Origen.interface.consume_comments
            # Origen.interface.descriptions.add_for_test_definition(name, c)
            suite
          end

          # Returns true if the given test suite name has already been added to the current flow.
          #
          # Pass in :global => true for all test flows to be considered.
          def duplicate?(name, options = {})
            files = existing_test_suites[name]
            if files && !files.empty?
              options[:global] || files.include?(filename)
            else
              false
            end
          end

          private

          def check_for_duplicates(name)
            if duplicate?(name)
              error "Duplicate test suite #{name} generated in #{filename}"
              exit 1
            elsif duplicate?(name, global: true)
              warning "Test suite #{name} is duplicated in: #{existing_test_suites[name].join(', ')}"
            end
          end

          def existing_test_suites
            @@existing_test_suites ||= {}
          end

          def record_test_suite(name)
            existing_test_suites[name] ||= []
            existing_test_suites[name] << filename
          end
        end
      end
    end
  end
end
