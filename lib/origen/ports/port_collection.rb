module Origen
  module Ports
    class PortCollection < ::Hash
      def add(name, port)
        self[name] = port
        by_type[port.type] ||= []
        by_type[port.type] << port
      end

      def by_type
        @by_type ||= {}.with_indifferent_access
      end

      def inspect
        map { |k, _v| k }.inspect
      end
    end
  end
end
