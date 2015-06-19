module RGen
  module Tester
    module Generator
      class TestNumberer
        # Will return a test number for the given test.
        #
        # @param [Hash] options Options to customize the number generation
        # @option options [Integer] :bits (6) The number of bits in the DAC code
        # @option options [Float] :range (1.26) The range parameter, see code formula
        # @option options [Integer] :offset (0) The o
        def test_number_for(_test_name, options = {})
          options = {

          }.merge(options)
        end

        private

        def store_file
          @store_file ||= Pathname.new "#{RGen.root}/.test_program/test_numbers"
        end
      end
    end
  end
end
