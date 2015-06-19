module RGen
  module Registers
    # This is a regular Ruby hash that is used to store collections of Reg objects, it has additional
    # methods added to allow interaction with the contained registers.
    # All Ruby hash methods are also available - http://www.ruby-doc.org/core/classes/Hash.html
    class RegCollection < Hash
      # Returns the object that owns the registers
      attr_reader :owner

      def initialize(owner, _options = {})
        @owner = owner
      end

      def inspect
        map { |k, _v| k }.inspect
      end

      # Display all regs visually in a console session
      def show
        puts map { |_k, v| v }.inspect
      end
    end
  end
end
