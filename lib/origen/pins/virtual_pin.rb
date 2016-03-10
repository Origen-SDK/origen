module Origen
  module Pins
    class VirtualPin < Pin
      def type=(value)
        @type = value
      end
    end
  end
end
