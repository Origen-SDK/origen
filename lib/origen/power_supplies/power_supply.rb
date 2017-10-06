require 'origen/specs'
module Origen
  module PowerSupplies
    class PowerSupply
      include Origen::Specs
      attr_accessor :id, :owner, :description, :type
      
      # Generic power supply number ... Usually will be the main power supply
      # with different power supplies coming from them.
      # Example:  GVDD will cover G1VDD, G2VDD, and G3VDD.
      attr_accessor :generic
      
      # More specific name, e.g. G1VDD
      attr_accessor :actual
      
      # Typical voltages for the actual power supply.  Could be multiple voltages
      # Expected type is Array
      attr_accessor :typ_voltages

      # Display Names
      # Should be Hash
      #  display_names = {
      #     input:  G1V<sub>IN</sub>
      #     output: G1V<sub>OUT</sub>
      #     nil:    G1V<sub>DD</sub>
      #}
      attr_accessor :display_names
      
     
      LIMITS = {
        min: 'Minimum',
        nom: 'Nominal',
        max: 'Maximum'
      }

      def initialize(id, options = {}, &block)
        @id = id
        @description = ''
        @conditions, @platforms = [], []
        @id = @id.symbolize unless @id.is_a? Symbol
        add_specs
        options.each { |k, v| instance_variable_set("@#{k}", v) }
        (block.arity < 1 ? (instance_eval(&block)) : block.call(self)) if block_given?
        fail unless attrs_ok?
      end

      def name
        @id
      end

      def display_names(name)
        @display_names = {}
        @display_names[:nil] = name
        @display_names[:input] = change_subscript('IN')
        @display_names[:output] = change_subscript('OUT')
        @display_names
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

      def add_specs
        LIMITS.each do |id, desc|
          spec id, :dc do
            description = desc
          end
        end
      end

      def change_subscript(new_subscript)
        tmp_display_name = @display_name[:nil].dup
        sub_input = tmp_display_name.at_css 'sub'
        sub_input.content = new_subscript unless sub_input.nil?
        tmp_display_name
      end
      
      def attrs_ok?
        return_value = true
        unless @description.is_a? String
          Origen.log.error("Test attribute 'description' must be a String!")
          return_value = false
        end
        return_value
      end
    end
  end
end
