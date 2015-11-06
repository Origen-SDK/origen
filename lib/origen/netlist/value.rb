module Origen
  module Netlist
    require 'delegate'
    class Value < ::Delegator
      def initialize(number)
        @number = number
      end

      def __getobj__
        @number
      end

      def to_v
        self
      end

      def terminal?
        true
      end

      def data(index = nil)
        if index
          self[index]
        else
          self
        end
      end
    end
  end
end
