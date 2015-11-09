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

      def data_bit(path, index, options = {})
        bits = data_bits(path, index, options)
        if bits.size > 1
          fail "Multiple data bit connections found for node #{path}[#{index}]"
        elsif bits.size == 0
          fail "No data bit connections found for node #{path}[#{index}]"
        end
        bits.first
      end

      def data_bits(path, index, options = {})
        processed_paths = options[:processed_paths] || []
        bits = []
        ['*', index].each do |i|
          unless processed_paths.include?("#{path}[#{i}]")
            processed_paths << "#{path}[#{i}]"
            vals = (table[path] || {})[i] || []
            vals.each do |val|
              if val.is_a?(Fixnum)
                bits << Registers::Bit.new(nil, index, access: :ro, data: i == '*' ? val[index] : val)
              else
                vp, vi = *to_v(val)
                bc = eval("top_level.#{vp}[#{vi || index}]")
                if bc.is_a?(Registers::BitCollection)
                  bits << bc.bit
                else
                  bits += data_bits(vp, vi || index, processed_paths: processed_paths) || []
                end
              end
            end
          end
        end
        bits.uniq
      end

      private

      def align(a, b)
        a, b = clean(a), clean(b)
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
          { path: path, numeric: true }
        else
          if path =~ /(.*)\[(\d+):?(\d*)\]$/
            if Regexp.last_match(3).empty?
              { path: Regexp.last_match(1), size: 1, indexes: [Regexp.last_match(2).to_i] }
            else
              a = ((Regexp.last_match(2).to_i)..(Regexp.last_match(3).to_i)).to_a
              { path: Regexp.last_match(1), size: a.size, indexes: a }
            end
          else
            { path: path }
          end
        end
      end

      def to_v(path)
        if path =~ /(.*)\[(\d+)\]$/
          [Regexp.last_match(1), Regexp.last_match(2).to_i]
        else
          [path, nil]
        end
      end
    end
  end
end
