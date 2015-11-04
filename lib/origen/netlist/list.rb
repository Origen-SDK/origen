module Origen
  module Netlist
    class List
      attr_reader :top_level, :table

      alias_method :parent, :top_level
      alias_method :owner, :top_level

      def initialize(top_level)
        @top_level = top_level
        @table = {}
      end

      def add(a, b)
        table[a.path] ||= {}
        table[b.path] ||= {}
        table[a.path][a.index] ||= []
        table[b.path][b.index] ||= []
        table[a.path][a.index] << b
        table[b.path][b.index] << a
      end

      def connections(vector)
        nets = (table[vector.path] || {}).select do |index, nets|
          !index || index == vector.index || overlap?(index, vector.index)
        end
        nets.values.flatten
      end

      private

      def overlap?(master, subset)
        master = to_array(master)
        to_array(subset).all? { |i| master.include?(i) }
      end

      def to_array(i)
        if i.is_a?(Range)
          first = i.first
          last = i.last
          if first > last
            (last..first).to_a
          else
            (first..last).to_a
          end
        else
          [i]
        end
      end
    end
  end
end
