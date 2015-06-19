module RGen
  module Registers
    class Domain
      attr_accessor :endian
      attr_accessor :name

      def initialize(name, options = {})
        options = {
          endian: :big
        }.merge(options)
        @name = name
        @endian = options[:endian]
      end
    end
  end
end
