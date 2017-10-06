module Origen
  module PowerDomains
    class PowerDomain
      attr_accessor :id, :description, :voltage_range, :nominal_voltage, :setpoint

      def initialize(id, options = {}, &block)
        @id = id
        @description = ''
        @id = @id.symbolize unless @id.is_a? Symbol
        options.each { |k, v| instance_variable_set("@#{k}", v) }
        (block.arity < 1 ? (instance_eval(&block)) : block.call(self)) if block_given?
        fail unless attrs_ok?
      end

      def name
        @id
      end

      def nominal_voltage
        @nominal_voltage
      end
      alias_method :nominal, :nominal_voltage
      alias_method :nom, :nominal_voltage

      def setpoint
        @setpoint
      end
      alias_method :curr_value, :setpoint
      alias_method :value, :setpoint

      def voltage_range
        @voltage_range
      end
      alias_method :range, :voltage_range

      def setpoint=(val)
        unless setpoint_ok?(val)
          Origen.log.warn("Setpoint (#{setpoint_string(val)}) for power domain '#{name}' is not within the voltage range (#{voltage_range_string})!")
        end
        @setpoint = val
      end

      def setpoint_ok?(val = nil)
        if val.nil?
          voltage_range.include?(setpoint) ? true : false
        else
          voltage_range.include?(val) ? true : false
        end
      end
      alias_method :value_ok?, :setpoint_ok?
      alias_method :val_ok?, :setpoint_ok?

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
        elsif voltage_range.nil?
          Origen.log.error("PPEKit: Missing voltage range for power domain '#{name}'!")
          false
        elsif voltage_range.is_a? Range
          if voltage_range.include?(nominal_voltage)
            true
          else
            Origen.log.error("PPEKit: Nominal voltage #{nominal_voltage} is not inbetween the voltage range #{voltage_range} for power domain '#{name}'!")
            false
          end
        else
          Origen.log.error("Power domain attribute 'voltage_range' must be a Range!")
          return_value = false
        end
      end
    end
  end
end
