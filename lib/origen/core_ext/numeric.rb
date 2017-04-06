class Numeric
  def undefined?
    false
  end

  def to_hex
    "0x#{to_s(16).upcase}"
  end

  def to_bin
    "0b#{to_s(2)}"
  end

  # Converts a number to a String representing binary number
  # Requires width of bit string for padding.  If the width is
  # less than the number of bits required to represent the number
  # the width argument is meaningless.
  def to_bitstring(width)
    '%0*b' % [width, self]
  end

  # Reverses the bit representation of a number and returns
  # the new value.  Useful when changing register data based on bit order
  def reverse_bits(width)
    result = 0
    0.upto(width - 1) do |i|
      result += self[i] * 2**(width - 1 - i)
    end
    result
  end

  #Msps ==> Mega samples per second
  
  %w(GHz Ghz GTs Gts Gsps).each do |m|
    define_method m do
      self * 1_000_000_000
    end
  end

  %w(MHz Mhz MTs Mts Msps).each do |m|
    define_method m do
      self * 1_000_000
    end
  end

  %w(GB).each do |m|
    define_method m do
      self * 1_024 * 1_024 * 1_024
    end
  end

  %w(MB).each do |m|
    define_method m do
      self * 1_024 * 1_024
    end
  end

  %w(to_GB).each do |m|
    define_method m do
      result = self / 1_024 / 1_024 / 1_024
      if result == Integer(result)
        return Integer(result)
      else
        return result
      end
    end
  end

  %w(to_MB).each do |m|
    define_method m do
      result = to_f / 1_024 / 1_024
      if result == Integer(result)
        return Integer(result)
      else
        return result
      end
    end
  end

  %w(kHz KHz Khz kO ko kOhm kohm ksps).each do |m|
    define_method m do
      self * 1_000
    end
  end

  %w(kB KB).each do |m|
    define_method m do
      self * 1_024
    end
  end

  %w(to_kB to_KB).each do |m|
    define_method m do
      result = to_f / 1_024
      if result == Integer(result)
        return Integer(result)
      else
        return result
      end
    end
  end

  %w(v V s S a A Hz Ts Ohm ohm O o).each do |m|
    define_method m do
      self
    end
  end

  %w(mv mV ms mS ma mA mo mO mOhm mohm).each do |m|
    define_method m do
      self / 1_000.0
    end
  end

  %w(uv uV us uS ua uA).each do |m|
    define_method m do
      self / 1_000_000.0
    end
  end

  %w(nv nV ns nS na nA).each do |m|
    define_method m do
      self / 1_000_000_000.0
    end
  end

  %w(pv pV ps pS pa pA).each do |m|
    define_method m do
      self / 1_000_000_000_000.0
    end
  end
end
