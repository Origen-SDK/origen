module RGen
  module Tester
    class JLink < CommandBasedTester
      def initialize
        super
        # The minimum time unit is 1ms
        set_timeset('default', 1_000_000)
        @pat_extension = 'jlk'
        @comment_char = '//'
      end

      def delay(cycles)
        microcode "Sleep #{cycles_to_ms(cycles)}"
      end

      def write_byte(address, data)
        microcode "w1 0x#{address.to_s(16).upcase}, 0x#{data.to_s(16).upcase}"
      end

      def write_word(address, data)
        microcode "w2 0x#{address.to_s(16).upcase}, 0x#{data.to_s(16).upcase}"
      end

      def write_longword(address, data)
        microcode "w4 0x#{address.to_s(16).upcase}, 0x#{data.to_s(16).upcase}"
      end

      def read(address, number_of_regs = 1)
        microcode "mem 0x#{address.to_s(16)}, #{number_of_regs}"
      end
    end
  end
end
