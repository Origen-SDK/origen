module Origen
  module Tester
    # A simple class to model a vector
    class Vector
      attr_accessor :repeat, :microcode, :timeset, :pin_vals,
                    :number, :cycle_number, :dont_compress,
                    :comments

      def initialize(attrs = {})
        attrs.each do |attribute, value|
          send("#{attribute}=", value)
        end
      end

      def comments
        @comments ||= []
      end

      def update(attrs = {})
        attrs.each do |attribute, value|
          send("#{attribute}=", value)
        end
      end

      # Updates the pin values to reflect the value currently held by the given pin
      def update_pin_val(pin)
        vals = pin_vals.split(' ')
        if pin.belongs_to_a_pin_group? && !pin.is_a?(Origen::Pins::PinCollection)
          port = nil
          pin.groups.each { |i| port = i[1] if port.nil? && Origen.tester.ordered_pins.include?(i[1]) } # see if group is included in ordered pins
          if port
            ix = Origen.tester.ordered_pins.index(port) # find index of port
            i = port.index(pin)
          else
            ix = Origen.tester.ordered_pins.index(pin)
            i = 0
          end
        else
          ix = Origen.tester.ordered_pins.index(pin)
          i = 0
        end

        if Origen.pin_bank.pin_groups.keys.include? pin.id
          val = pin.map { |p| Origen.tester.format_pin_state(p) }.join('')
          vals[ix] = val
        else
          val = Origen.tester.format_pin_state(pin)
          vals[ix][i] = val
        end

        self.pin_vals = vals.join(' ')
      end

      def ordered_pins
        Origen.app.pin_map.sort_by { |_id, pin| pin.order }.map { |_id, pin| pin }
      end

      def microcode=(val)
        if has_microcode? && @microcode != val
          fail "Trying to assign microcode: #{val}, but vector already has microcode: #{@microcode}"
        else
          @microcode = val
        end
      end

      # Since repeat 0 is non-intuitive every vector implicitly has a repeat of 1
      def repeat
        @repeat || 1
      end

      def has_microcode?
        @microcode && !@microcode.empty?
      end

      def ==(obj)
        if obj.is_a?(Vector)
          self.has_microcode? == obj.has_microcode? &&
            timeset == obj.timeset &&
            pin_vals == obj.pin_vals
        else
          super obj
        end
      end
    end
  end
end
