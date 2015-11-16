require 'delegate'
module Origen
  class SizedNumber < ::Delegator
    attr_reader :size

    def initialize(number, size=0)
      if number.is_a?(Symbol) || number.is_a?(String)
        number = number.to_s
        if number =~ /^b(\d+)_([10_]+)$/
          size = Regexp.last_match(1).to_i
          number = Regexp.last_match(2).gsub('_', '').to_i(2)
        elsif number =~ /^h(\d+)_([0-9a-fA-F_]+)$/
          size = Regexp.last_match(1).to_i
          number = Regexp.last_match(2).gsub('_', '').to_i(16)
        elsif number =~ /^d(\d+)_([0-9_]+)$/
          size = Regexp.last_match(1).to_i
          number = Regexp.last_match(2).gsub('_', '').to_i
        else
          fail "Bad formatted sized-number :#{number}, should be in the format :b4_1010, :h16_55DF or :d4_9"
        end
      elsif !size
        fail "A size argument must be given when creating a new sized number from a numeric value"
      end
      @number = number & ((2**size)-1)
      @size = size
    end

    def __getobj__
      @number
    end

    def to_bin
      '0b%0*b' % [size, @number]
    end

    def to_hex
      '0x%0*X' % [size / 4, @number]
    end
  end
end
