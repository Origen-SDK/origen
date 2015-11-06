module Origen
  module Netlist
    require 'delegate'
    class Vector < ::Delegator
      attr_reader :path, :index, :root_object

      TERMINALS = [
        Registers::BitCollection,
        Registers::Reg,
        Registers::Bit
      ]

      def initialize(path, index, root_object)
        @path = path
        @index = index
        @root_object = root_object
      end

      def to_v
        self
      end
      alias_method :to_vector, :to_v

      def __getobj__
        @obj ||= instance_eval("root_object.#{path}")
      end

      def inspect
        "<Vector:#{object_id}; path: #{path}; index: #{index}>"
      end

      def terminal?
        @terminal ||= TERMINALS.any? { |c| __getobj__.is_a?(c) }
      end

      def ==(vector)
        vector.is_a?(Vector) &&
          path == vector.path &&
          index == vector.index &&
          root_object == vector.root_object
      end
    end
  end
end
