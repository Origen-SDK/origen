module Origen
  class XNumber
    attr_reader :size, :mask

    def initialize(number)
      number = number.to_s

      if number =~ /^b(\d+)_([10xX_]+)$/
        @size = Regexp.last_match(1).to_i
        str = Regexp.last_match(2).gsub('_', '').upcase
        v = ((1 << @size) - 1)
        @value = str.gsub('X', '0').to_i(2) & v
        @mask = str.gsub('0', '1').gsub('X', '0').rjust(@size, '1').to_i(2) & v
        @format = :bin
      elsif number =~ /^h(\d+)_([0-9a-fA-FxX_]+)$/
        @size = Regexp.last_match(1).to_i
        str = Regexp.last_match(2).gsub('_', '').upcase
        v = ((1 << @size) - 1)
        @value = str.gsub('X', '0').to_i(16) & v
        @mask = str.gsub(/[0-9A-F]/, 'F').gsub('X', '0').rjust(@size / 4, 'F').to_i(16) & v
        @format = :hex
      else
        fail "Bad formatted X-number #{number}, should be in the format :b4_1X10 or :h16_55X0"
      end
    end

    def inspect
      to_s
    end

    def to_s
      @to_s ||= begin
        str = ''
        if @format == :bin
          size.times do |i|
            if mask[i] == 0
              str = "X#{str}"
            else
              str = "#{@value[i]}#{str}"
            end
          end
          "0b#{str}"
        else
          (size / 4).times do |i|
            j = i * 4
            if mask[(j + 3)..j] == 0
              str = "X#{str}"
            else
              str = "#{@value[(j + 3)..j]}#{str}"
            end
          end
          "0x#{str}"
        end
      end
    end

    def ==(val)
      if val.is_a?(Origen::XNumber)
        val = val.instance_variable_get('@value')
      end
      if val.is_a?(Numeric)
        val <= mask &&
          (val & mask) == @value
      else
        super
      end
    end
  end
end
