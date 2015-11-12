require 'delegate'
module Origen
  class SizedNumber < ::Delegator
    attr_reader :size

    def initialize(number, size)
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
