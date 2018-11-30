module Origen
  module Registers
    require 'delegate'

    # Thin wrapper around pin objects to modify bit number interpretation
    #
    # This is provided as a convenience to make user code more readable
    class Msb0Delegator < ::Delegator
      def initialize(reg_object)
        @reg_object = reg_object
      end

      def __getobj__
        @reg_object
      end

      def __object__
        @reg_object
      end

      def inspect
        @reg_object.inspect with_bit_order: true
      end
    end
    
  end
end
  