module Origen
  module Netlist
    module Connectable
      extend ActiveSupport::Concern

      included do
        include Origen::Netlist
      end

      def connect_to(node, options = {})
        if node.is_a?(Fixnum)
          node = Value.new(node)
        elsif node.is_a?(String)
          node = Connectable.path_to_vector(node, netlist_top_level)
        end
        netlist.add(to_v, node.to_v)
      end
      alias_method :connected_to, :connect_to
      alias_method :connect, :connect_to

      def connections
        netlist.connections(to_v)
      end
      alias_method :nets, :connections

      def terminals(processed_vectors = [])
        vectors = []
        nets.each do |vector|
          if vector.terminal?
            vectors << vector
          else
            unless processed_vectors.include?(vector)
              processed_vectors << vector
              if vector.respond_to?(:terminals)
                vectors += vector.terminals(processed_vectors)
              end
            end
          end
        end
        vectors.uniq
      end

      def terminal_node?
        to_v.terminal?
      end

      def data_from_netlist
        if terminal_node?
          data
        else
          t = terminals
          if t.size > 1
            fail 'Multiple terminal nodes found!'
          elsif t.size == 0
            fail 'No terminal node found!'
          else
            t.first.data(to_v.index)
          end
        end
      end

      def to_v
        Connectable.path_to_vector(path, netlist_top_level)
      end
      alias_method :to_vector, :to_v

      def self.path_to_vector(path, top_level_object)
        # http://rubular.com/r/4eBMdIjusV
        if path =~ /(.*)\[(\d+):?(\d*)\]$/
          if Regexp.last_match(3).empty?
            Vector.new(Regexp.last_match(1), Regexp.last_match(2).to_i, top_level_object)
          else
            Vector.new(Regexp.last_match(1), (Regexp.last_match(2).to_i)..(Regexp.last_match(3).to_i), top_level_object)
          end
        else
          Vector.new(path, nil, top_level_object)
        end
      end
    end
  end
end
