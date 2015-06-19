require 'active_support/core_ext/string/inflections'
begin
  require 'scrub_rb'
rescue LoadError
  # Temporary patch as the scrub_rb gem is not installed to the central Ruby installation.
  # This means that when running RGen outside of an application this functionality is not
  # available (which is fine), within an application the gem will be loaded correctly by
  # Bundler and the gem will require quite happily.
end

class String
  def to_dec
    if self =~ /0x(.*)/
      Regexp.last_match[1].to_i(16)
    elsif self =~ /0b(.*)/
      Regexp.last_match[1].to_i(2)
    else
      to_i
    end
  end

  def escape_underscores
    gsub('_', '\_')
  end
  alias_method :escape_underscore, :escape_underscores

  def camel_case
    RGen.deprecate "String#camel_case! is deprecated, use String#camelcase instead, or if you want to get rid of spaces: my_string.gsub(' ', '_').camelcase"
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
    gsub(/(\n|\s|\(|\)|\.|\[|\]|-|{|})/, '_').downcase.to_sym
  end

  # acronyms
  def to_snakecase!
    RGen.deprecate 'String#to_snakecase! is deprecated, use String#underscore instead since it is aware of FSL acronyms'
    gsub!(/\s+/, '')
    g = gsub!(/(.)([A-Z])/, '\1_\2');
    d = downcase!
    g || d
  end
  alias_method :snakecase!, :to_snakecase!

  def to_snakecase
    RGen.deprecate 'String#to_snakecase is deprecated, use String#underscore instead since it is aware of FSL acronyms'
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
end
