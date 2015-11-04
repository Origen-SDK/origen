module Origen
  module Netlist
    Vector = Struct.new(:path, :index) do
      def to_v
        self
      end
      alias_method :to_vector, :to_v
    end
  end
end
