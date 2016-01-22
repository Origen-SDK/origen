module Origen
  module Specs
    # This class is used to store mode select for IP
    class Mode_Select
      # Block Name at the SoC (e.g. DDRC1, DDRC2, DDRC3)
      attr_accessor :block

      # Data Sheet Header/Group Name
      attr_accessor :ds_header

      # Block Use at the SoC Level
      attr_accessor :usage

      # Mode Reference Name
      attr_accessor :mode

      # SoC Supports this mode?
      attr_accessor :supported

      # SoC Supply List
      attr_accessor :supply

      # SoC Supply Voltage Level
      attr_accessor :supply_level

      # Use Information from different data source
      attr_accessor :diff_loc

      # Location of the block to read
      attr_accessor :location

      # There are three sub-blocks of information in Mode Select
      # * block_information:
      # ** name : The name of the block as instiniated in the SoC
      # ** ds_header:  Data Sheet Header/Group.  Allows for multiple instantation to be grouped under one header in datasheet or allows for them to broken out
      # ** usage:  Block is used in this SoC {Could be starting point for license plate support}
      # ** location:  File path to the specml location
      #
      # * mode_usage:
      # ** mode: The mode name at the IP Level
      # ** usage: Does this IP in this SoC support this mode?
      #
      # * power_information:
      # ** supply:  Name of the supply for that Interface.
      # ** voltage_level:  Array of the possible values for this supply e.g. [1.8, 2.5, 3.3] or [1.8]
      # ** use_diff:  Use information from a different location
      def initialize(block_information, mode_usage, power_information)
        @block = block_information[:name]
        @ds_header = block_information[:ds_header]
        @usage = block_information[:usage]
        @location = block_information[:location]
        @mode = mode_usage[:mode]
        @supported = mode_usage[:supported]
        @supply = power_information[:supply]
        @supply_level = power_information[:voltage_level]
        @diff_loc = power_information[:use_diff]
      end
    end
  end
end
