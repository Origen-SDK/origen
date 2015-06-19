module RGen
  module Tester
    class Ultraflex
      class Parser
        class PatternSets < RGen::Tester::Parser::SearchableHash
          attr_accessor :parser

          def initialize(options = {})
            @parser = options[:parser]
          end

          def import(file)
            File.readlines(file).each do |line|
              name = PatternSet.extract_name(line)
              if name
                if self[name]
                  self[name].add_pattern_line(line)
                else
                  l = PatternSet.new(line, parser: parser)
                  self[l.name] = l if l.valid?
                end
              end
            end
          end

          def inspect
            "<Patsets: #{size}>"
          end
        end
      end
    end
  end
end
