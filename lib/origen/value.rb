module Origen
  # This class wraps various different class which handle number representation in
  # various formats.
  #
  # The user should never instantiate those directly and should always instantiate an
  # Origen::Value instance, thereby ensuring a common API regardless of the internal
  # representation and handling of the value
  class Value
    autoload :HexStrVal, 'origen/value/hex_str_val'
    autoload :BinStrVal, 'origen/value/bin_str_val'

    # Represents a single bit value of 'X'
    class X
      def z?
        false
      end
      alias_method :hi_z?, :z?

      def x?
        true
      end
      alias_method :undefined?, :x?

      def x_or_z?
        true
      end
      alias_method :z_or_x?, :x_or_z?
    end

    # Represents a single bit value of 'Y'
    class Z
      def z?
        true
      end
      alias_method :hi_z?, :z?

      def x?
        false
      end
      alias_method :undefined?, :x?

      def x_or_z?
        true
      end
      alias_method :z_or_x?, :x_or_z?
    end

    def initialize(val, options = {})
      if val.is_a?(Integer)
        @val = val
      else
        val = val.to_s
        case val[0].downcase
        when 'b'
          @val = BinStrVal.new(val, options)
        when 'h'
          @val = HexStrVal.new(val, options)
        when 'd'
          @val = val.to_s[1..-1].to_i
        else
          if  val =~ /^[0-9]+$/
            @val = val.to_i
          else
            fail 'Unsupported value syntax'
          end
        end
      end
    end

    # Returns true if all bits have a numeric value - i.e. no X or Z
    def numeric?
      val.numeric?
    end

    def value?
      true
    end

    # Converts to an integer, returns nil if the value contains non-numeric bits
    def to_i
      val.to_i
    end

    # Converts to a string, the format of it depends on the underlying value type
    def to_s
      val.to_s
    end

    # Returns the size of the value in bits
    def size
      val.size
    end
    alias_method :bits, :size
    alias_method :number_of_bits, :size

    def hex_str_val?
      val.is_a?(HexStrVal)
    end
    alias_method :hex_str_value?, :hex_str_val?

    def bin_str_val?
      val.is_a?(BinStrVal)
    end
    alias_method :bin_str_value?, :bin_str_val?

    def [](index)
      if index.is_a?(Range)
        fail 'Currently, only single bit extraction from a Value object is supported'
      end
      val[index]
    end

    private

    def val
      @val
    end
  end
end
