module Origen
  module Registers
    require 'delegate'

    # Thin wrapper around register objects to modify bit number interpretation
    #
    # This is provided as a convenience to make user code more readable
    class Msb0Delegator < ::Delegator
      def initialize(reg_object, bits)
        @reg_object = reg_object
        @bits = bits
      end

      def __getobj__
        @reg_object
      end

      def __object__
        @reg_object
      end

      def __setobj__(obj)
        @reg_object = obj
      end

      def inspect
        @reg_object.inspect with_bit_order: :msb0
      end

      def method_missing(method, *args, &block)
        args << { with_bit_order: :msb0 }
        @reg_object.method_missing(method, args, &block)
      end

      def bit(*args)
        @reg_object.bit(args, with_bit_order: :msb0)
      end
      alias_method :bits, :bit
      alias_method :[], :bit
    end
  end
end
