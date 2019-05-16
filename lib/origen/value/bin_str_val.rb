module Origen
  class Value
    # Handles a value represented by a string of bin character(s) [0, 1, x, z]
    #
    # Capital X/Z will be accepted when defining the value, but they will be converted
    # to lower case
    class BinStrVal
      attr_reader :val, :size

      def initialize(value, options)
        @val = clean(value)
        if options[:size]
          @size = options[:size]
          # Trim any bits that are out of range...
          @val = val.split(//).last(size).join
        else
          @size = val.size
        end
      end

      def numeric?
        !!(val =~ /^[01]+$/)
      end

      def to_i
        if numeric?
          val.to_i(2) & size.bit_mask
        end
      end

      def to_s
        "b#{val}"
      end

      # Returns the value of the given bit.
      # Return nil if out of range, otherwise 0, 1 or an X or Z object
      def [](index)
        unless index > (size - 1)
          if numeric?
            to_i[index]
          else
            char = val[val.size - 1 - index]
            if char == 'x'
              X.new
            elsif char == 'z'
              Z.new
            else
              char.to_i
            end
          end
        end
      end

      private

      def clean(val)
        val = val.to_s.strip.to_s[1..-1]
        if valid?(val)
          val.gsub('_', '').downcase
        end
      end

      def valid?(val)
        if val =~ /^[01_xXzZ]+$/
          true
        else
          fail Origen::BinStrValError, "Binary string values can only contain: 0, 1, _, x, X, z, Z, this is invalid: #{val}"
        end
      end
    end
  end
end
