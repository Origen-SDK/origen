module RGen
  module Specs
    # This class is used to store mode select for IP
    class Mode_Select
      attr_accessor :block, :usage, :mode, :supported, :location

      def initialize(blk, use, mode_ref, support, loc)
        @block = blk
        @usage = use
        @mode = mode_ref
        @supported = support
        @location = loc
      end
    end
  end
end
