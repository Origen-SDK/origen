module Origen
  module Pins
    class PowerPin < Pin
      # Set the operating voltage for the pin, can be a single value or an array
      def voltage=(val)
        @voltages = [val].flatten.uniq
      end

      # Like voltages but if there is only one voltage known then it will be returned
      # directly instead of being wrapped in an array.
      # If no voltages are known this returns nil whereas voltages will return an
      # empty array.
      # For more than one voltages present this behaves like an alias of voltages.
      def voltage
        if voltages.size > 0
          if voltages.size > 1
            voltages
          else
            voltages.first
          end
        end
      end

      # Returns an array of known operating voltages for the given pin
      def voltages
        @voltages ||= []
      end
    end
  end
end
