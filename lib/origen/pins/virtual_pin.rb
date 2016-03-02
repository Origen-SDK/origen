module Origen
  module Pins
    class VirtualPin < Pin
      # Pin Types
      TYPES = [:virtual_bit, :ate_ch]

      def type=(value)
        if TYPES.include? value
          @type = value
        else
          fail "VirtualPin type '#{value}' must be set to one of the following: #{TYPES.join(', ')}"
        end
      end
    end
  end
end
