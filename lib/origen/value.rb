module Origen
  # This class wraps various different class which handle number representation in
  # various formats.
  #
  # The user should never instantiate those directly and should always instantiate an
  # Origen::Value instance, thereby ensuring a common API regardless of the internal
  # representation and handling of the value
  class Value
    autoload :HexStrVal, 'origen/value/hex_str_val'

    # Represents a single bit value of 'X'
    class X
      def z?
        false
      end

      def x?
        true
      end
    end

    # Represents a single bit value of 'Y'
    class Z
      def z?
        true
      end

      def x?
        false
      end
    end

    def initialize(val, options = {})
      if val.to_s =~ /^h/
        @val = HexStrVal.new(val, options)
      else
        fail 'Unsupported value syntax'
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

    private

    def val
      @val
    end
  end
end
