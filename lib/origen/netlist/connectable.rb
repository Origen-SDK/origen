module Origen
  module Netlist
    module Connectable
      extend ActiveSupport::Concern

      included do
        include Origen::Netlist
      end

      def connect_to(node, options = {})
        node = node.path if node.respond_to?(:path)
        netlist.connect(path, node)
      end
      alias_method :connect, :connect_to
    end
  end
end
