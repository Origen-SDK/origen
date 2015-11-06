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

      # Connect two paths together in the netlist, one can be a numeric
      # value to represent a logic level connection
      def connect(a, b)
        align(a, b) do |path, index, target|
          table[path] ||= {}
          table[path][index] ||= []
          table[path][index] << target
        end
      end

      def connections(vector)
        nets = (table[vector.path] || {}).select do |index, nets|
          !index || index == vector.index || overlap?(index, vector.index)
        end
        nets.values.flatten
      end

      private

      def align(a, b)
        a,b = clean(a), clean(b)
        if a[:size] || b[:size]
          if a[:size] && b[:size]
            size = [a[:size], b[:size]].min
          else
            size = a[:size] || b[:size]
          end

          unless a[:numeric]
            size.times do |i|
              index = a[:indexes] ? a[:indexes][i] : i
              if b[:numeric]
                target = b[:path][i]
              else
                if b[:indexes]
                  target = "#{b[:path]}[#{b[:indexes][i]}]"
                else
                  target = "#{b[:path]}[#{i}]"
                end
              end
              yield a[:path], index, target
            end
          end

          unless b[:numeric]
            size.times do |i|
              index = b[:indexes] ? b[:indexes][i] : i
              if a[:numeric]
                target = a[:path][i]
              else
                if a[:indexes]
                  target = "#{a[:path]}[#{a[:indexes][i]}]"
                else
                  target = "#{a[:path]}[#{i}]"
                end
              end
              yield b[:path], index, target
            end
          end

        else
          yield a[:path], '*', b[:path] unless a[:numeric]
          yield b[:path], '*', a[:path] unless b[:numeric]
        end
      end

      def clean(path)
        if path.is_a?(Fixnum)
          {path: path, numeric: true}
        else
          if path =~ /(.*)\[(\d+):?(\d*)\]$/
            if Regexp.last_match(3).empty?
              {path: $1, size: 1, indexes: [$2.to_i]}
            else
              a = ((Regexp.last_match(2).to_i)..(Regexp.last_match(3).to_i)).to_a
              {path: $1, size: a.size, indexes: a}
            end
          else
            {path: path}
          end 
        end
      end

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
