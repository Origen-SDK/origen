require 'origen/specs'
module Origen
  module PowerDomains
    class PowerDomain
      include Origen::Specs
      attr_accessor :id, :description, :unit_voltage_range, :nominal_voltage, :setpoint, :maximum_voltage_rating, :min, :max

      # Generic Power Domain Name
      # This is the power supply that can be blocked off to multiple power supplies
      # For example, Power Domain for DDR blocks could be GVDD, then the actual
      # power supplies can be different for each DDR block.
      #  DDR1 --> G1VDD
      #  DDR2 --> G2VDD
      attr_accessor :generic_name

      # Actual Power Domain Name
      attr_accessor :actual_name

      # Allowed Voltage Points
      # Some power supplies can be at different levels, e.g. 1.8V or 3.3V
      # Could be a signal voltage or an array of voltages
      attr_accessor :voltages

      # Display Names
      # Hash of display names
      # display_name = {
      #   input:  Input voltage name, e.g. V<sub>IN</sub>
      #   output:  Output voltage name, e.g. V<sub>OUT</sub>
      #   default: Regular Voltage name, e.g. V<sub>DD</sub>
      attr_accessor :display_name

      def initialize(id, options = {}, &block)
        @id = id
        @description = ''
        @display_name = {}
        @id = @id.symbolize unless @id.is_a? Symbol
        options.each { |k, v| instance_variable_set("@#{k}", v) }
        (block.arity < 1 ? (instance_eval(&block)) : block.call(self)) if block_given?
        @unit_voltage_range = :fixed if @unit_voltage_range.nil?
        fail unless attrs_ok?
        create_dut_spec unless @min.nil? || @max.nil?
      end

      def name
        @id
      end

      # Create DUT specs for the power supply
      def create_dut_spec
        if Origen.top_level.specs.nil?
          set_specs
        elsif Origen.top_level.specs.include? name
          Origen.log.error("Cannot create power domain spec '#{name}', it already exists!")
          fail
        else
          set_specs
        end
      end

      # Maximum Voltage Rating
      def maximum_voltage_rating
        @maximum_voltage_rating
      end
      alias_method :mvr, :maximum_voltage_rating

      # Sets setpoint equal to nominal_voltage
      def setpoint_to_nominal
        @setpoint = @nominal_voltage
      end

      # Returns an Array of all pins that reference the power domain
      def pins
        signal_pins + ground_pins + power_pins
      end

      # Returns an Array of signal pin IDs that match the power domain ID
      def signal_pins
        Origen.top_level.pins.select { |_pin_id, p| p.supply == id }.keys
      end

      # Returns an Array of ground pin IDs that match the power domain ID
      def ground_pins
        Origen.top_level.ground_pins.select { |_pin_id, p| p.supply == id }.keys
      end

      # Returns an Array of ground pin IDs that match the power domain ID
      def power_pins
        Origen.top_level.power_pins.select { |_pin_id, p| p.supply == id }.keys
      end

      # Checks for the existence of a signal pin that references the power domain
      def has_signal_pin?(pin)
        signal_pins.include?(pin) ? true : false
      end

      # Checks for the existence of a signal pin that references the power domain
      def has_ground_pin?(pin)
        ground_pins.include?(pin) ? true : false
      end

      # Checks for the existence of a signal pin that references the power domain
      def has_power_pin?(pin)
        power_pins.include?(pin) ? true : false
      end

      # Checks if a pin references the power domain, regardless of type
      def has_pin?(pin)
        pins.include? pin
      end

      # Checks for a pin type, returns nil if it is not found
      def pin_type(pin)
        if self.has_pin?(pin) == false
          nil
        else
          [:signal, :ground, :power].each do |pintype|
            return pintype if send("has_#{pintype}_pin?", pin)
          end
        end
      end

      # Nominal voltage
      def nominal_voltage
        @nominal_voltage
      end
      alias_method :nominal, :nominal_voltage
      alias_method :nom, :nominal_voltage

      # Current setpoint, defaults top nil on init
      def setpoint
        @setpoint
      end
      alias_method :curr_value, :setpoint
      alias_method :value, :setpoint

      # Power domain can allow either a variable
      # or fixed unit voltage range (Range or :fixed)
      def unit_voltage_range
        @unit_voltage_range
      end
      alias_method :unit_range, :unit_voltage_range

      # Setter for setpoint
      def setpoint=(val)
        unless setpoint_ok?(val)
          Origen.log.warn("Setpoint (#{setpoint_string(val)}) for power domain '#{name}' is not within the voltage range (#{unit_voltage_range_string})!")
        end
        @setpoint = val
      end

      # Checks if the setpoint is valid
      # This will need rework once the class has spec limits added
      def setpoint_ok?(val = nil)
        return true if maximum_voltage_rating.nil?
        compare_val = val.nil? ? setpoint : val
        if compare_val.nil?
          false
        elsif compare_val <= maximum_voltage_rating
          true
        else
          false
        end
      end
      alias_method :value_ok?, :setpoint_ok?
      alias_method :val_ok?, :setpoint_ok?

      def display_names(default_name)
        @display_name[:default] = default_name
        @display_name[:input] = change_subscript('IN')
        @display_name[:output] = change_subscript('OUT')
      end

      def method_missing(m, *args, &block)
        ivar = "@#{m.to_s.gsub('=', '')}"
        ivar_sym = ":#{ivar}"
        if m.to_s =~ /=$/
          define_singleton_method(m) do |val|
            instance_variable_set(ivar, val)
          end
        elsif instance_variables.include? ivar_sym
          instance_variable_get(ivar)
        else
          define_singleton_method(m) do
            instance_variable_get(ivar)
          end
        end
        send(m, *args, &block)
      end

      private

      def set_specs
        Origen.top_level.spec name, :dc do |s|
          s.description = "#{name.to_s.upcase} Power Domain"
          s.min = min
          s.typ = nominal_voltage
          s.max = max
          s.unit = 'V'
        end
      end

      def attrs_ok?
        return_value = true
        unless description.is_a? String
          Origen.log.error("Power domain attribute 'description' must be a String!")
          return_value = false
        end
        return_value = false unless voltages_ok?
        return_value
      end

      def setpoint_string(val = nil)
        if val.nil?
          setpoint.as_units('V')
        else
          val.as_units('V')
        end
      end

      def voltages_ok?
        if nominal_voltage.nil?
          false
        elsif unit_voltage_range == :fixed
          true
        elsif unit_voltage_range.nil?
          Origen.log.error("PPEKit: Missing unit voltage range for power domain '#{name}'!")
          false
        elsif unit_voltage_range.is_a? Range
          unless unit_voltage_range.include?(nominal_voltage)
            Origen.log.error("PPEKit: Nominal voltage #{nominal_voltage} is not inbetween the unit voltage range #{unit_voltage_range} for power domain '#{name}'!")
            false
          end
          unless maximum_voltage_rating.nil?
            unless unit_voltage_range.last <= maximum_voltage_rating
              Origen.log.error('PPEKit: Unit voltage range exceeds the maximum voltage range!')
              fail
            end
          end
          true
        else
          Origen.log.error("Power domain attribute 'unit_voltage_range' must be a Range or set to the value of :fixed!")
          return_value = false
        end
      end

      def change_subscript(new_subscript)
        tmp = @display_name[:default].dup
        sub_input = tmp.at_css 'sub'
        sub_input.content = new_subscript unless sub_input.nil?
        tmp
      end
    end
  end
end
