module Origen
  class Value
    # Handles a value represented by a string of hex character(s) [0-9, a-f, x, X, z, Z]
    #
    # This is
    #
    # * x when all the bits in a nibble are x
    # * X when some of the bits in a nibble are x, though the exact bit-level values are not known
    # * z when all the bits in a nibble are z
    # * Z when some of the bits in a nibble are z, though the exact bit-level values are not known
    #
    # Capital hex numbers will be accepted when defining the value, but they will be converted
    # to lower case
    class HexStrVal
      attr_reader :val, :size

      def initialize(value, options)
        @val = clean(value)
        if options[:size]
          @size = options[:size]
          # Trim any nibbles that are out of range...
          @val = val.split(//).last(size_in_nibbles).join
        else
          @size = (val.size * 4)
        end
      end

      def numeric?
        !!(val =~ /^[0-9a-f]+$/)
      end

      def to_i
        if numeric?
          val.to_i(16) & size.bit_mask
        end
      end

      def to_s
        val
      end

      # Returns the value of the given bit.
      # Return nil if out of range, otherwise 0, 1 or an X or Z object
      def [](index)
        unless index > (size - 1)
          if numeric?
            to_i[index]
          else
            # Get the nibble in question and re-align the index, if the bit falls in a numeric
            # part of the string we can still resolve to an integer
            nibble = nibble_of(index)
            nibble = val[val.size - 1 - nibble]
            if nibble.downcase == 'x'
              X.new
            elsif nibble.downcase == 'z'
              Z.new
            else
              nibble.to_i[index % 4]
            end
          end
        end
      end

      private

      def nibble_of(bit_number)
        bit_number / 4
      end

      # Rounds up to the nearest whole nibble
      def size_in_nibbles
        adder = size % 4 == 0 ? 0 : 1
        (size / 4) + adder
      end

      def clean(val)
        val = val.to_s.strip.to_s[1..-1]
        if valid?(val)
          if val =~ /[A-F]/
            val = val.gsub('A', 'a')
            val = val.gsub('B', 'b')
            val = val.gsub('C', 'c')
            val = val.gsub('D', 'd')
            val = val.gsub('E', 'e')
            val = val.gsub('F', 'f')
          end
          val.gsub('_', '')
        end
      end

      def valid?(val)
        if val =~ /^[0-9a-fA-F_xXzZ]+$/
          true
        else
          fail Origen::SyntaxError, 'Hex string values can only contain: 0-9, a-f, A-F, _, x, X, y, Y'
        end
      end
    end
  end
end
