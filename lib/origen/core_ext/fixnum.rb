class Fixnum
  # Extend Fixnum to enable 10.cycles
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

  alias_method :old_bit_select, :[]
  def [](*args)
    if args.length == 1 && !args.first.is_a?(Range)
      old_bit_select(args.first)
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

  def ones_comp(num_bits)
    self ^ ((1 << num_bits) - 1)
  end
  alias_method :ones_complement, :ones_comp
  alias_method :ones_compliment, :ones_comp

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
end
