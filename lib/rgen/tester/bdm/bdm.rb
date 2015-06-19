module RGen
  module Tester
    class BDM < CommandBasedTester
      def initialize
        super
        # The minimum time unit is 0.1s
        set_timeset('default', 100_000_000)
        @pat_extension = 'cmd'
        @comment_char = '//'
      end

      def delay(cycles)
        microcode "WAIT #{cycles_to_ts(cycles)}"
      end

      def write_byte(address, data)
        microcode "WB 0x#{address.to_s(16).upcase} 0x#{data.to_s(16).upcase}"
      end

      def write_word(address, data)
        microcode "WW 0x#{address.to_s(16).upcase} 0x#{data.to_s(16).upcase}"
      end
    end
  end
end
