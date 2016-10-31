module Origen
  module Specs
    # This class is used to store Power Supply Information at the SoC Level
    class Power_Supply
      # Generic Power Supply Name.  For example:
      # *  GVDD
      # *  DVDD
      # *  TVDD
      # *  EVDD
      attr_accessor :generic

      # The Actual Power Supply Name.  For example, GVDD could be the generic name and actual names can be G1VDD and G2VDD.
      # GVDD ==> {G1VDD, G2VDD, G3VDD}
      # DVDD ==> {D1VDD, D2VDD}
      attr_accessor :actual

      # Voltages for the power supply.  Needs to be supplied by a different source
      # Voltages is an array for all possible values for that power supply
      # DVDD ==>
      #   * 1.8 V
      #   * 3.3 V
      attr_accessor :voltages

      # Display Name for the Voltage.  Will be in html/dita code
      # G1VDD -->  G1V<sub>DD</sub>
      attr_accessor :display_name

      # Input Display Name for the Voltage
      # G1VDD --> G1V<sub>IN</sub>
      attr_accessor :input_display_name

      # Output Displat Name for the Voltage
      # G1VDD --> G1V<sub>OUT</sub>
      attr_accessor :output_display_name

      # Initialize the variables
      def initialize(gen, act)
        @generic = gen
        @actual = act
        @voltages = []
        @display_name = ''
        @input_display_name = ''
        @output_display_name = ''
      end

      def update_input
        @input_display_name = change_subscript('IN')
      end

      def update_output
        @output_display_name = change_subscript('OUT')
      end

      def change_subscript(new_subscript)
        temp_display_name = @display_name.dup
        sub_input = temp_display_name.at_css 'sub'
        sub_input.content = new_subscript unless sub_input.nil?
        temp_display_name
      end
    end
  end
end
