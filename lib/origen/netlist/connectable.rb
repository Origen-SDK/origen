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

      def connections
        netlist.connections(to_v)
      end
      alias_method :nets, :connections

      def terminals(processed_vectors = [])
        nodes = []
        nets.each do |vector|
          if vector.terminal?
            nodes << vector
          else
            unless processed_vectors.include?(vector)
              processed_vectors << vector
              if vector.respond_to?(:terminals)
                nodes += vector.terminals(processed_vectors)
              end
            end
          end
        end
        nodes.uniq
      end

      def data_from_netlist
        t = terminals
        if t.size > 1
          fail 'Multiple terminal nodes found!'
        elsif t.size == 0
          fail 'No terminal node found!'
        else
          if i = to_v.index
            t.first.data[i]
          else
            t.first.data
          end
        end
      end

      def to_v
        Connectable.path_to_vector(path, netlist_top_level)
      end

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
