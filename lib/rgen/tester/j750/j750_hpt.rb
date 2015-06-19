module RGen
  module Tester
    # rubocop:disable ClassAndModuleCamelCase

    # Tester model to generate .atp patterns for the Teradyne J750 in HPT mode
    #
    # == Basic Usage
    #   $tester = J750_HPT.new
    #   $tester.cycle       # Generate a vector
    #
    # Many more methods exist to generate J750 specific micro-code, see J750
    # parent class definition for details.
    #
    # *Also note that this class inherits from the base Tester class and so all methods
    # described there are also available*
    class J750_HPT < J750
      def initialize
        super
        @@hpt_mode = true
        @drive_hi_state = '.1'
        @drive_lo_state = '.0'
        @expect_hi_state = '.H'
        @expect_lo_state = '.L'
        @dont_care_state = '.X'
        @overlay_state = '.V'
        @drive_very_hi_state = '.2'
        @drive_mem_state = '.D'
        @expect_mem_state = '.E'
        @name = 'j750_hpt'
      end
    end

    # rubocop:enable ClassAndModuleCamelCase
  end
end
