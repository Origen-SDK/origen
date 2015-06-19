module RGen
  module Specs
    # This class is used to store override information for specified specs on instantiated IP
    class Override
      attr_accessor :block, :usage, :spec_ref, :mode_ref, :sub_type, :audience, :minimum, :maximum, :typical, :disable

      def initialize(block_options = {}, find_spec = {}, values = {}, options = {})
        @block = block_options[:block]
        @usage = block_options[:usage]
        @spec_ref = find_spec[:spec_id]
        @mode_ref = find_spec[:mode_ref]
        @sub_type = find_spec[:sub_type]
        @audience = find_spec[:audience]
        @minimum = values[:min]
        @maximum = values[:max]
        @typical = values[:typ]
        @disable = options[:disable]
      end
    end
  end
end
