module Origen
  module Tester
    class V93K
      module Generator
        class TestFunctions
          # Origen::Tester::Generator not included since test functions do not have their
          # own top-level sheet, they will be incorporated within the flow sheet

          attr_accessor :flow, :collection

          def initialize(flow)
            @flow = flow
            @collection = {}
            @ix = 0
          end

          def filename
            flow.filename
          end

          def add(name, type, options = {})
            check_for_duplicates(name)
            record_test_function(name)
            func = TestFunction.new(next_name, type, options)
            @collection[name] = func
            # c = Origen.interface.consume_comments
            # Origen.interface.descriptions.add_for_test_definition(name, c)
            func
          end

          def functional(name, options = {})
            add(name, :functional, options)
          end

          def [](name)
            @collection[name]
          end

          # Returns true if the given test function name has already been added to the current flow.
          #
          # Pass in :global => true for all test flows to be considered.
          def duplicate?(name, options = {})
            files = existing_test_functions[name]
            if files && !files.empty?
              options[:global] || files.include?(filename)
            else
              false
            end
          end

          private

          def next_name
            @ix += 1
            "tf_#{@ix}"
          end

          def check_for_duplicates(name)
            if duplicate?(name)
              error "Duplicate test function #{name} generated in #{filename}"
              exit 1
            elsif duplicate?(name, global: true)
              warning "Test function #{name} is duplicated in: #{existing_test_functions[name].join(', ')}"
            end
          end

          def existing_test_functions
            @@existing_test_functions ||= {}
          end

          def record_test_function(name)
            existing_test_functions[name] ||= []
            existing_test_functions[name] << filename
          end
        end
      end
    end
  end
end
