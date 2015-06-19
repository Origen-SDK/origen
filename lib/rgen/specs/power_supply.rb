module RGen
  module Specs
    # This class is used to store Power Supply Information at the SoC Level
    class Power_Supply
      attr_accessor :generic, :actual

      def initialize(gen, act)
        @generic = gen
        @actual = act
      end
    end
  end
end
