module Origen
  module Ports
    class Section
      attr_reader :port
      attr_reader :index

      def initialize(port, index)
        @port = port
        @index = index
      end

      def size
        size_of(index)
      end

      def path
        if index.is_a?(Range)
          port.path + "[#{index.first}:#{index.last}]"
        else
          port.path + "[#{index}]"
        end
      end

      def parent
        port.parent
      end
      alias_method :owner, :parent

      def id
        port.id
      end

      # def drive(value = nil)
      #  port.drive(value, index: index)
      # end

      # def drive_value
      #  if size == 1
      #    port.drive_values[index]
      #  else
      #    fail 'drive_value is only supported for a single bit port section'
      #  end
      # end

      def data
        if port.data == undefined
          undefined
        else
          port.data[index]
        end
      end

      def [](index)
        Section.new(port, align_to_port(index))
      end

      private

      def size_of(index)
        if index.is_a?(Range)
          (index.first - index.last).abs + 1
        else
          1
        end
      end

      def align_to_port(val)
        if val.is_a?(Range)
          nlsb = lsb + val.last
          nmsb = nlsb + size_of(val) - 1
          out_of_range(val) if nmsb > msb
          i = nmsb..nlsb
        else
          i = lsb + val
          out_of_range(val) if i > msb
        end
        i
      end

      def out_of_range(val)
        fail "Requested section index (#{val}) is out of range for a port section of size #{size}"
      end

      def msb
        if index.is_a?(Range)
          index.first
        else
          index
        end
      end

      def lsb
        if index.is_a?(Range)
          index.last
        else
          index
        end
      end
    end
  end
end
