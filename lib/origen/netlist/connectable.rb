module Origen
  module Netlist
    module Connectable
      extend ActiveSupport::Concern

      included do
        include Origen::Netlist
      end

      def connect_to(node = nil, options = {}, &block)
        node, options = nil, node if node.is_a?(Hash)
        node = node.path if node.respond_to?(:path)
        netlist.connect(path, node, &block)
      end
      alias_method :connect, :connect_to
    end
  end
end
