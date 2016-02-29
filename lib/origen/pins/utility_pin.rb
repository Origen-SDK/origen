module Origen
  module Pins
    class UtilityPin < Pin
      # Pin Types
      TYPES = [:utility_bit, :ate_ch]

      def type=(value)
        if TYPES.include? value
          @type = value
        else
          fail "UtilityPin type '#{value}' must be set to one of the following: #{TYPES.join(', ')}"
        end
      end
    end
  end
end
