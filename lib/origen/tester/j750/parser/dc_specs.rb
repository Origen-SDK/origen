module Origen
  module Tester
    class J750
      class Parser
        class DCSpecs < Origen::Tester::Parser::SearchableHash
          attr_accessor :parser

          def initialize(options = {})
            @parser = options[:parser]
          end

          def import(file)
            @categories = []
            File.readlines(file).each do |line|
              unless line.strip.empty?
                components = line.split("\t")
                if components[3] == 'Selector'
                  extract_categories(components)
                else
                  unless components[1] == 'DC Specs' || components[1] == 'Symbol'
                    extract_spec(components)
                  end
                end
              end
            end
          end

          def inspect
            "<DCSpecs: #{size}>"
          end

          def extract_categories(components)
            components.each_with_index do |val, i|
              if i > 4
                @categories << val unless val.strip.empty?
              end
            end
            @categories.uniq!
          end

          def extract_spec(components)
            name = components[1]
            self[name] ||= DCSpec.new(name, @categories, parser: parser)
            self[name].add_values(components)
          end
        end
      end
    end
  end
end
