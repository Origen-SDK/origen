module Origen
  module Tester
    class V93K
      module Generator
        class Pattern
          attr_accessor :name

          def initialize(name, _options = {})
            self.name = name
            Origen.interface.referenced_patterns << name
          end
        end
      end
    end
  end
end
