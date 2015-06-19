module RGen
  module Pins
    class PinClock
      attr_accessor :running
      attr_accessor :cycles_per_half_period
      attr_accessor :last_edge
      attr_accessor :next_edge

      def initialize(owner, options = {})
        @owner = owner
        @running = false
        @cycles_per_half_period = 0
        @ns_per_half_period = 0
        update_half_period(options)
      end

      def running?
        @running
      end

      def start_clock(options = {})
        fail "ERROR: Clock on #{@owner.name} already running." if running?

        if update_required?(options)
          update_half_period(options)
        end

        @last_edge = RGen.tester.cycle_count
        @next_edge = RGen.tester.cycle_count + @cycles_per_half_period
        cc "Start clock on #{@owner.name}: cycles_per_half_period=#{@cycles_per_half_period}, start cycle=#{@last_edge}"
        RGen.tester.push_running_clock(@owner) unless running?
        @running = true
      end

      def restart_clock(_options = {})
        stop_clock
        update_clock
        start_clock
      end

      def stop_clock(_options = {})
        cc "Stop clock on #{@owner.name}: stop cycle=#{RGen.tester.cycle_count}" if running?
        RGen.tester.pop_running_clock(@owner) if running?
        @running = false
      end

      def update_clock
        unless update_half_period(period_in_ns: @ns_per_half_period)
          @last_edge = RGen.tester.cycle_count
          @next_edge = RGen.tester.cycle_count + @cycles_per_half_period
        end
      end

      def toggle
        @owner.toggle
        @last_edge = RGen.tester.cycle_count
        @next_edge = RGen.tester.cycle_count + @cycles_per_half_period
      end

      private

      def update_half_period(options = {})
        old_cycles_per_half_period = @cycles_per_half_period
        options = { cycles: 0,
                    period_in_s: 0, period_in_ms: 0, period_in_us: 0, period_in_ns: 0,
                    frequency_in_hz: 0, frequency_in_khz: 0, frequency_in_mhz: 0,
                    freq_in_hz: 0, freq_in_khz: 0, freq_in_mhz: 0
                  }.merge(options)

        cycles = 0
        cycles += options[:cycles]
        cycles += s_to_cycles(options[:period_in_s])
        cycles += ms_to_cycles(options[:period_in_ms])
        cycles += us_to_cycles(options[:period_in_us])
        cycles += ns_to_cycles(options[:period_in_ns])
        cycles += hz_to_cycles(options[:frequency_in_hz])
        cycles += khz_to_cycles(options[:frequency_in_khz])
        cycles += mhz_to_cycles(options[:frequency_in_mhz])
        cycles += hz_to_cycles(options[:freq_in_hz])
        cycles += khz_to_cycles(options[:freq_in_khz])
        cycles += mhz_to_cycles(options[:freq_in_mhz])

        @cycles_per_half_period = cycles / 2
        @ns_per_half_period = cycles * RGen.tester.current_period_in_ns
        @cycles_per_half_period == old_cycles_per_half_period
      end

      def s_to_cycles(time) # :nodoc:
        ((time.to_f) * 1000 * 1000 * 1000 / RGen.tester.current_period_in_ns).to_int
      end

      def ms_to_cycles(time) # :nodoc:
        ((time.to_f) * 1000 * 1000 / RGen.tester.current_period_in_ns).to_int
      end

      def us_to_cycles(time) # :nodoc:
        ((time.to_f * 1000) / RGen.tester.current_period_in_ns).to_int
      end

      def ns_to_cycles(time) # :nodoc:
        (time.to_f / RGen.tester.current_period_in_ns).to_int
      end

      def hz_to_cycles(freq) # :nodoc:
        (freq == 0) ? freq : s_to_cycles(1 / freq.to_f)
      end

      def khz_to_cycles(freq) # :nodoc:
        (freq == 0) ? freq : ms_to_cycles(1 / freq.to_f)
      end

      def mhz_to_cycles(freq) # :nodoc:
        (freq == 0) ? freq : us_to_cycles(1 / freq.to_f)
      end

      def update_required?(options)
        options[:cycles] ||
          options[:period_in_s] || options[:period_in_ms] || options[:period_in_us] || options[:period_in_ns]
        options[:frequency_in_hz] || options[:frequency_in_khz] || options[:frequency_in_mhz] ||
          options[:freq_in_hz] || options[:freq_in_khz] || options[:freq_in_mhz]
      end
    end
  end
end
