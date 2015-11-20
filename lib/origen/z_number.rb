module Origen
  class ZNumber
    attr_reader :size, :mask

    def initialize(number)
      if number.is_a?(Numeric)
        @size = number
        @value = 0
        @format = (@size % 4) == 0 ? :hex : :bin
        @mask = 0
      else
        number = number.to_s

        if number =~ /^b(\d+)_([10zZ_]+)$/
          @size = Regexp.last_match(1).to_i
          str = Regexp.last_match(2).gsub('_', '').upcase
          v = ((1 << @size) - 1)
          @value = str.gsub('Z', '0').to_i(2) & v
          @mask = str.gsub('0', '1').gsub('Z', '0').rjust(@size, '1').to_i(2) & v
          @format = :bin
        elsif number =~ /^h(\d+)_([0-9a-fA-FzZ_]+)$/
          @size = Regexp.last_match(1).to_i
          str = Regexp.last_match(2).gsub('_', '').upcase
          v = ((1 << @size) - 1)
          @value = str.gsub('Z', '0').to_i(16) & v
          @mask = str.gsub(/[0-9A-F]/, 'F').gsub('Z', '0').rjust(@size / 4, 'F').to_i(16) & v
          @format = :hex
        else
          fail "Bad formatted Z-number #{number}, should be in the format :b4_1Z10 or :h16_55Z0"
        end
      end
    end

    def inspect
      to_s
    end

    def to_s(format = nil)
      if format
        @to_s = nil
      end
      format ||= @format
      @to_s ||= begin
        str = ''
        if format == :bin
          size.times do |i|
            if mask[i] == 0
              str = "Z#{str}"
            else
              str = "#{@value[i]}#{str}"
            end
          end
          "0b#{str}"
        else
          (size / 4).times do |i|
            j = i * 4
            if mask[(j + 3)..j] == 0
              str = "Z#{str}"
            else
              str = "#{@value[(j + 3)..j]}#{str}"
            end
          end
          "0x#{str}"
        end
      end
    end

    def |(val)
      if val.is_a?(Origen::ZNumber)
        fail 'Bitwise OR of two Z numbers is not implemented yet'
      end
      if val.is_a?(Numeric)
        val | @value
      else
        super
      end
    end

    def <<(val)
      ZNumber.new("b#{size + val}_#{to_s(:bin).sub('0b', '')}" + ('0' * val))
    end

    def to_i
      @value
    end
  end
end
