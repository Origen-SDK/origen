module Origen
  module Models
    class ScanRegister
      include Origen::Model

      attr_reader :size
      attr_accessor :mode

      def initialize(options = {})
        reg :sr, 0, size: size

        port :si
        port :so
        port :u, size: size
        port :c, size: size

        so.connect_to(sr[0])
        u.connect_to(sr)

        @mode = :shift
      end

      def mode=(val)
        unless [:shift, :capture].include?(val)
          fail "Unknown scan register mode, #{val}, must be either :shift or :capture"
        end
        @mode = val
      end

      def clock_prepare
        if mode == :shift
          @din = si.data
        else
          @din = c.data
        end
      end

      def clock_apply
        if mode == :shift
          sr.shift_right(@din)
        else
          sr.write(@din)
        end
        @din = nil
      end
    end
  end
end
