module Origen
  module Ports
    class Section
      include Netlist::Connectable

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

      def [](index)
        Section.new(port, align_to_port(index))
      end

      def respond_to?(*args)
        super(*args) || BitCollection.instance_methods.include?(args.first)
      end

      def method_missing(method, *args, &block)
        if BitCollection.instance_methods.include?(method)
          to_bc.send(method, *args, &block)
        else
          super
        end
      end

      def to_bc
        b = BitCollection.new(port, port.id)
        indexes = index.respond_to?(:to_a) ? index.to_a : [index]
        indexes.reverse_each do |i|
          b << netlist.data_bit(port.path, i)
        end
        b
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
