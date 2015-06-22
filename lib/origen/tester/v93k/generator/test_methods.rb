module Origen
  module Tester
    class V93K
      module Generator
        class TestMethods
          # Origen::Tester::Generator not included since test methods do not have their
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

          def add(name, _type, options = {})
            check_for_duplicates(name)
            record_test_method(name)
            func = TestMethod.new(next_name, options)
            @collection[name] = func
            # c = Origen.interface.consume_comments
            # Origen.interface.descriptions.add_for_test_definition(name, c)
            func
          end

          def [](name)
            @collection[name]
          end

          # Returns true if the given test method name has already been added to the current flow.
          #
          # Pass in :global => true for all test flows to be considered.
          def duplicate?(name, options = {})
            files = existing_test_methods[name]
            if files && !files.empty?
              options[:global] || files.include?(filename)
            else
              false
            end
          end

          private

          def next_name
            @ix += 1
            "tm_#{@ix}"
          end

          def check_for_duplicates(name)
            if duplicate?(name)
              error "Duplicate test method #{name} generated in #{filename}"
              exit 1
            elsif duplicate?(name, global: true)
              warning "Test method #{name} is duplicated in: #{existing_test_methods[name].join(', ')}"
            end
          end

          def existing_test_methods
            @@existing_test_methods ||= {}
          end

          def record_test_method(name)
            existing_test_methods[name] ||= []
            existing_test_methods[name] << filename
          end
        end
      end
    end
  end
end
