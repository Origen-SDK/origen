module Origen
  module Tester
    class J750
      class Parser
        class TestInstances < Origen::Tester::Parser::SearchableHash
          attr_accessor :parser

          def initialize(options = {})
            @parser = options[:parser]
          end

          def import(file)
            File.readlines(file).each do |line|
              l = TestInstance.new(line, parser: parser)
              self[l.name] = l if l.valid?
            end
          end

          def inspect
            "<TestInstances: #{size}>"
          end
        end
      end
    end
  end
end
