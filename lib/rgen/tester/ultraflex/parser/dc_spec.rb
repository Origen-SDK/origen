module RGen
  module Tester
    class Ultraflex
      class Parser
        class DCSpec
          attr_accessor :parser
          attr_accessor :name, :categories
          alias_method :symbol, :name

          def initialize(name, categories, options = {})
            @parser = options[:parser]
            @name = name
            @categories = categories
            @values = {}
          end

          def add_values(components)
            @categories.each_with_index do |category, i|
              @values[category] ||= {}
              @values[category]['Typ'] ||= components[5 + (i * 3) + 0]
              @values[category]['Min'] ||= components[5 + (i * 3) + 1]
              @values[category]['Max'] ||= components[5 + (i * 3) + 2]
            end
          end

          def lookup(category, selector)
            v = @values[category]
            if v
              v[selector]
            end
          end
        end
      end
    end
  end
end
