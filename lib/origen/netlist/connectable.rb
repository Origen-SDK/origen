module Origen
  module Netlist
    module Connectable
      extend ActiveSupport::Concern

      included do
        include Origen::Netlist
      end

      def connect_to(node, options = {})
        if node.is_a?(Fixnum)
          node = Vector.new(node, nil)
        elsif node.is_a?(String)
          node = Connectable.path_to_vector(node)
        end
        netlist.add(to_v, node.to_v)
      end
      alias_method :connected_to, :connect_to
      alias_method :connect, :connect_to

      def connections
        netlist.connections(to_v)
      end
      alias_method :nets, :connections

      def data_from_netlist
        nets.each do |net|
          if net.path.is_a?(Fixnum)
            if i = to_v.index
              return net.path[i]
            else
              if size == 1
                return net.path[0]
              else
                return net.path[(size - 1)..0]
              end
            end
          else
            fail 'Not implemented yet'
          end
        end
        fail "Data value unknown for node #{path}"
      end

      def to_v
        Connectable.path_to_vector(path)
      end
      alias_method :to_vector, :to_v

      def self.path_to_vector(path)
        # http://rubular.com/r/4eBMdIjusV
        if path =~ /(.*)\[(\d+):?(\d*)\]$/
          if Regexp.last_match(3).empty?
            Vector.new(Regexp.last_match(1), Regexp.last_match(2).to_i)
          else
            Vector.new(Regexp.last_match(1), (Regexp.last_match(2).to_i)..(Regexp.last_match(3).to_i))
          end
        else
          Vector.new(path, nil)
        end
      end
    end
  end
end
