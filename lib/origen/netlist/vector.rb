module Origen
  module Netlist
    require 'delegate'
    class Vector < ::Delegator
      attr_reader :path, :index, :root_object

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
        @obj ||= begin
          if path.is_a?(::Object::Fixnum)
            path
          else
            instance_eval "root_object.#{path}"
          end
        end
      end

      def inspect
        "<Vector:#{object_id}; path: #{path}; index: #{index}>"
      end

      def terminal?
        path.is_a?(Fixnum)
      end

      def data
        if path.is_a?(Fixnum)
          if index
            return path[index]
          else
            if size == 1
              return path[0]
            else
              return path[(size - 1)..0]
            end
          end
        elsif path.is_a?(String)
          fail 'Not implemented yet'
        else
          fail 'Not implemented yet'
        end
        path
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
