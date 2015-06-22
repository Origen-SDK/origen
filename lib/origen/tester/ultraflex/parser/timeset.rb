module Origen
  module Tester
    class Ultraflex
      class Parser
        class Timeset
          attr_accessor :parser

          def initialize(options = {})
            @parser = options[:parser]
          end
        end
      end
    end
  end
end
