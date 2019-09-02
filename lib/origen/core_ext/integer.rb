# The base class of ALL integers, i.e. including Fixum and Bignum

# Shim to handle Ruby < 2.4.0, where [] is implemented in Fixnum/Bignum instead
# of Integer
module Origen
  module IntegerExtension
    def [](*args)
      if args.length == 1 && !args.first.is_a?(Range)
        super
      else
        if args.first.is_a?(Range)
          msb = args.first.first
          lsb = args.first.last
        else
          msb = args.first
          lsb = args.last
        end
        (self >> lsb) & 0.ones_comp(msb - lsb + 1)
      end
    end
  end
end

class Integer
  class << self
    attr_accessor :width
  end
  @width = 32

  if RUBY_VERSION >= '2.4.0'
    prepend Origen::IntegerExtension
  end

  # Implements 10.cycles
  def cycles
    if block_given?
      times do
        yield
        Origen.app.tester.cycle
      end
    else
      Origen.app.tester.cycle(repeat: self)
    end
  end
  alias_method :cycle, :cycles

  def ones_comp(num_bits)
    self ^ ((1 << num_bits) - 1)
  end
  alias_method :ones_complement, :ones_comp
  alias_method :ones_compliment, :ones_comp

  # Returns a bit mask for the given number of bits:
  #
  #   4.to_bit_mask  # => 0x1111
  def to_bit_mask
    (1 << self) - 1
  end
  alias_method :bit_mask, :to_bit_mask

  def to_bool
    if self == 1
      return true
    elsif self == 0
      return false
    else
      return nil
    end
  end

  def to_spreadsheet_column
    index_hash = Hash.new { |hash, key| hash[key] = hash[key - 1].next }.merge(0 => 'A')
    index_hash[self]
  end
  alias_method :to_xls_column, :to_spreadsheet_column
  alias_method :to_xlsx_column, :to_spreadsheet_column
  alias_method :to_xls_col, :to_spreadsheet_column
  alias_method :to_xlsx_col, :to_spreadsheet_column
  alias_method :to_spreadsheet_col, :to_spreadsheet_column

  def twos_complement(width=nil)
    _width = width || Integer.width
    if self > 2**(_width-1) - 1
      raise(RangeError, "Integer #{self} cannot fit into #{_width} bits with 2s complement encoding")
    elsif self < -1 * (2**(_width-1))
      raise(RangeError, "Integer #{self} cannot fit into #{_width} bits with 2s complement encoding")
    end
    
    self < 0 ? ((-1*self)^(2**_width - 1)) + 1 : self
  end
  alias_method :twos_comp, :twos_complement
  alias_method :twos_compliment, :twos_complement
end

if RUBY_VERSION <= '2.4.0'
  class Fixnum
    prepend Origen::IntegerExtension
  end

  class Bignum
    prepend Origen::IntegerExtension
  end
end
