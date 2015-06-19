module RGen
  module Tester
    class Doc
      module Generator
        class Tests
          attr_accessor :collection

          def initialize
            @collection = []
          end

          class IndexedString < ::String
            attr_accessor :index

            def name
              self
            end
          end

          def add(name, attrs = {})
            test = Test.new(name, attrs)
            if @current_group
              @current_group << test
            else
              collection << test
            end
            test
          end

          # Arbitrarily group a subset of tests together, see the J750 API for details on how to use
          # this.
          def group(name = nil, options = {})
            name, options = nil, name if name.is_a?(Hash)
            @current_group = TestGroup.new(name, options)
            collection << @current_group
            yield @current_group
            @current_group = nil
          end
          alias_method :add_group, :group

          def render(_file, _options = {})
          end
        end
      end
    end
  end
end
