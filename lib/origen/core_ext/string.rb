require 'active_support/core_ext/string/inflections'
begin
  require 'scrub_rb'
rescue LoadError
  # Temporary patch as the scrub_rb gem is not installed to the central Ruby installation.
  # This means that when running Origen outside of an application this functionality is not
  # available (which is fine), within an application the gem will be loaded correctly by
  # Bundler and the gem will require quite happily.
end

class String
  def to_dec
    if self.is_verilog_number?
      verilog_to_dec
    elsif match(/^0[x,o,d,b]\S+/)
      _to_dec(self)
    else
      to_i
    end
  end

  def escape_underscores
    gsub('_', '\_')
  end
  alias_method :escape_underscore, :escape_underscores

  def camel_case
    Origen.deprecate "String#camel_case! is deprecated, use String#camelcase instead, or if you want to get rid of spaces: my_string.gsub(' ', '_').camelcase"
    gsub(/\s+/, '_').split('_').map(&:capitalize).join
  end

  def pad_leading_zeros(width)
    str = self
    (0..(width - size) - 1).each { str = '0' + str }
    str
  end

  def to_lines(length)
    lines = []
    line = []
    len = 0
    split(/\s+/).each do |word|
      if (len + word.length) > length
        lines << line.join(' ')
        line = []
        len = 0
      end
      line << word
      len += word.length + 1 # For the trailing space
    end
    lines << line.join(' ') unless line.empty?
    lines
  end

  # Sanitizes the string for conversion to a symbol and returns a lower
  # cased symbol version of the string
  def symbolize
    orig_had_leading_underscore = match(/^\_/) ? true : false
    orig_had_trailing_underscore = match(/\_$/) ? true : false
    new_str = gsub(/(\?|\!|\-|\/|\\|\n|\s|\(|\)|\.|\[|\]|-|{|})/, '_').downcase
    # Get rid of adjacent underscores
    new_str.match(/\_\_/) ? new_str = new_str.squeeze('_') : new_str
    new_str.chomp!('_') unless orig_had_trailing_underscore
    unless orig_had_leading_underscore
      new_str = new_str[1..-1] if new_str.match(/^\_/)
    end
    @@symbolize ||= {}
    @@symbolize[self] ||= new_str.to_sym
  end

  # acronyms
  def to_snakecase!
    Origen.deprecate 'String#to_snakecase! is deprecated, use String#underscore instead since it is aware of FSL acronyms'
    gsub!(/\s+/, '')
    g = gsub!(/(.)([A-Z])/, '\1_\2');
    d = downcase!
    g || d
  end
  alias_method :snakecase!, :to_snakecase!

  def to_snakecase
    Origen.deprecate 'String#to_snakecase is deprecated, use String#underscore instead since it is aware of FSL acronyms'
    dup.tap(&:to_snakecase!)
  end
  alias_method :snakecase, :to_snakecase

  def squeeze_lines
    split(/\n+/).join(' ').squeeze(' ')
  end

  # Attempt to convert a String to a boolean answer
  def to_bool
    if self == true || self =~ (/^(true|t|yes|y|1)$/i)
      return true
    elsif self == false || self.empty? || self =~ (/^(false|f|no|n|0)$/i)
      return false
    else
      return nil
    end
  end

  # Check if a String is a numeric
  def is_numeric?
    return true if self =~ /\A\d+\Z/
    true if Float(self) rescue false # rubocop:disable Style/RescueModifier
  end
  alias_method :numeric?, :is_numeric?

  # Convert the String to a Numeric (Float or Integer)
  def to_numeric
    if self.numeric?
      if to_i == to_f
        to_i
      else
        to_f
      end
    else
      fail "'#{self}' cannot be converted to a Numeric, exiting..."
    end
  end
  alias_method :to_number, :to_numeric

  # Capitalize every word
  def titleize(options = {})
    options = {
      keep_specials: false
    }.update(options)
    if options[:keep_specials]
      split.map(&:capitalize).join(' ')
    else
      split(/ |\_|\-/).map(&:capitalize).join(' ')
    end
  end

  def is_verilog_number?
    case self
    when /^[b,o,d,h]\S+$/, /^\d+\'[b,o,d,h]\S+$/, /^\d+\'s[b,o,d,h]\S+$/
      true
    else
      false
    end
  end

  # Boolean if the string is uppercase
  # Will not work with odd character sets
  def is_upcase?
    self == upcase
  end
  alias_method :is_uppercase?, :is_upcase?

  # Boolean if the string is uppercase
  # Will not work with odd character sets
  def is_downcase?
    self == downcase
  end
  alias_method :is_lowercase?, :is_downcase?

  # Convert Excel/Spreadsheet column to integer
  def excel_col_index
    str = split('').map(&:upcase).join('')
    offset = 'A'.ord - 1
    str.chars.inject(0) { |x, c| x * 26 + c.ord - offset }
  end
  alias_method :xls_col_index, :excel_col_index
  alias_method :xlsx_col_index, :excel_col_index
  alias_method :spreadsheet_col_index, :excel_col_index

  private

  # Convert a verilog number string to an integer
  def verilog_to_dec
    verilog_hash = parse_verilog_number
    bit_str = verilog_to_bits
    msb_size_bit = bit_str.size - verilog_hash[:size]
    if verilog_hash[:signed] == true
      if bit_str[msb_size_bit] == '1'
        _to_dec("0b#{bit_str}") * -1
      else
        _to_dec("0b#{bit_str}")
      end
    else
      _to_dec("0b#{bit_str}")
    end
  end

  # Convert a verilog number string to a bit string
  def verilog_to_bits
    verilog_hash = parse_verilog_number
    if [verilog_hash[:radix], verilog_hash[:value]].include?(nil)
      Origen.log.error("The string '#{self}' does not appear to be valid Verilog number notation!")
      fail
    end
    value_bit_string = create_bit_string_from_verilog(verilog_hash[:value], verilog_hash[:radix])
    audit_verilog_value(value_bit_string, verilog_hash[:radix], verilog_hash[:size], verilog_hash[:signed])
  end

  def _to_dec(str)
    if str =~ /^0x(.*)/i
      Regexp.last_match[1].to_i(16)
    elsif str =~ /0d(.*)/i
      Regexp.last_match[1].to_i(10)
    elsif str =~ /0o(.*)/i
      Regexp.last_match[1].to_i(8)
    elsif str =~ /0b(.*)/
      Regexp.last_match[1].to_i(2)
    end
  end

  def parse_verilog_number
    str = nil
    verilog_hash = {}.tap do |parse_hash|
      [:size, :radix, :value].each do |attr|
        parse_hash[attr] = nil
      end
    end
    verilog_hash[:signed] = false
    if match(/\_/)
      str = delete('_')
    else
      str = self
    end
    str.downcase!
    case str
    when /^[0,1]+$/ # Just a value
      verilog_hash[:size], verilog_hash[:radix], verilog_hash[:value] = 32, 'b', self
    when /^[b,o,d,h]\S+$/ # A value and a radix
      _m, verilog_hash[:radix], verilog_hash[:value] = /^([b,o,d,h])(\S+)$/.match(str).to_a
      verilog_hash[:size] = calc_verilog_value_bit_size(verilog_hash[:value], verilog_hash[:radix])
    when /^\d+\'[b,o,d,h]\S+$/ # A value, a radix, and a size
      _m, verilog_hash[:size], verilog_hash[:radix], verilog_hash[:value] = /^(\d+)\'([b,o,d,h])(\S+)$/.match(str).to_a
    when /^\d+\'s[b,o,d,h]\S+$/ # A signed value, a radix, and a size
      _m, verilog_hash[:size], verilog_hash[:radix], verilog_hash[:value] = /^(\d+)\'s([b,o,d,h])(\S+)$/.match(str).to_a
      verilog_hash[:signed] = true
    else
      Origen.log.error("The string '#{self}' does not appear to be valid Verilog number notation!")
      fail
    end
    verilog_hash[:size] = verilog_hash[:size].to_i if verilog_hash[:size].is_a?(String)
    verilog_hash
  end

  def calc_verilog_value_bit_size(val, radix)
    create_bit_string_from_verilog(val, radix).size
  end

  def create_bit_string_from_verilog(val, radix)
    bit_str = ''
    case radix
    when 'b'
      return val
    when 'o', 'd'
      bit_str = "0#{radix}#{val}".to_dec.to_bin
    when 'h'
      bit_str = "0x#{val}".to_dec.to_bin
    end
    2.times { bit_str.slice!(0) }
    bit_str
  end

  def audit_verilog_value(bit_str, radix, size, signed)
    size_diff = bit_str.size - size
    if size_diff > 0
      Origen.log.warn("Truncating Verilog number '#{self}' by #{size_diff} MSBs!")
      size_diff.times { bit_str.slice!(0) }
    elsif size_diff < 0
      bit_str = '0' * size_diff.abs + bit_str
    end
    bit_str
  end
end
