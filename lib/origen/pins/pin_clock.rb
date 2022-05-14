module Origen
  module Pins
    class PinClock
      attr_reader :cycles_per_duty, :last_edge, :next_edge

      def initialize(owner, options = {})
        @owner = owner
        @running = false

        @clock_period_in_ns = 0
        @tester_period_in_ns = 0

        update_clock_period(options)
        update_tester_period_local
        update_clock_parameters
      end

      def start_clock(options = {})
        # Throw error if this pin is already a running clock
        if running?
          fail "PIN CLOCK ERROR: Clock on #{@owner.name} already running."
        end

        clock_updated = update_clock_period(options)
        tester_updated = update_tester_period_local
        if clock_updated || tester_updated
          update_clock_parameters
        end

        cc "[PinClock] Start #{@owner.name}.clock at #{Origen.tester.cycle_count}: period=#{@clock_period_in_ns}ns, cycles=#{cycles_per_period}, duty=#{duty_str}"
        update_edges
        Origen.tester.push_running_clock(@owner) unless running?
        @running = true
      end

      def stop_clock(options = {})
        cc "[PinClock] Stop #{@owner.name}.clock: stop_cycle=#{Origen.tester.cycle_count}" if running?
        Origen.tester.pop_running_clock(@owner) if running?
        @running = false
      end

      def restart_clock
        stop_clock
        update_clock
        start_clock
      end

      def update_clock
        if update_tester_period_local
          update_clock_parameters
          cc "[PinClock] Update #{@owner.name}.clock at #{Origen.tester.cycle_count}: period=#{@clock_period_in_ns}ns, cycles=#{cycles_per_period}, duty=#{duty_str}"
          update_edges
        end
      end

      def running?
        @running
      end

      def toggle
        @owner.toggle
        update_edges
      end

      # The only caller to this should be legacy support so just force 50% duty cycle
      def cycles_per_half_period
        @cycles_per_duty.min
      end

      private

      def update_clock_parameters
        @cycles_per_duty = [(cycles_per_period / 2.0).floor, (cycles_per_period / 2.0).ceil]
      end

      def cycles_per_period
        (@clock_period_in_ns / @tester_period_in_ns).to_int
      end

      def update_edges
        @last_edge = Origen.tester.cycle_count
        @next_edge = Origen.tester.cycle_count + @cycles_per_duty[0]
        @cycles_per_duty.reverse!
      end

      def update_tester_period_local
        if Origen.tester.current_period_in_ns == @tester_period_in_ns
          return false
        else
          @tester_period_in_ns = Origen.tester.current_period_in_ns
          return true
        end
      end

      def update_clock_period(options = {})
        new = get_clock_period(options)

        if new == @clock_period_in_ns
          false
        else
          @clock_period_in_ns = new
          true
        end
      end

      def get_clock_period(options = {})
        return @clock_period_in_ns if options.empty?

        p = []

        # Passed in as time
        p << (options[:period_in_s] * 1_000_000_000) if options[:period_in_s]
        p << (options[:period_in_ms] * 1_000_000) if options[:period_in_ms]
        p << (options[:period_in_us] * 1_000) if options[:period_in_us]
        p << (options[:period_in_ns] * 1) if options[:period_in_ns]

        # Passed in as frequency (or freq.)
        p << ((1.0 / options[:frequency_in_hz]) * 1_000_000_000) if options[:frequency_in_hz]
        p << ((1.0 / options[:freq_in_hz]) * 1_000_000_000) if options[:freq_in_hz]
        p << ((1.0 / options[:frequency_in_khz]) * 1_000_000) if options[:frequency_in_khz]
        p << ((1.0 / options[:freq_in_khz]) * 1_000_000) if options[:freq_in_khz]
        p << ((1.0 / options[:frequency_in_mhz]) * 1_000) if options[:frequency_in_mhz]
        p << ((1.0 / options[:freq_in_mhz]) * 1_000) if options[:freq_in_mhz]

        # Passed in as cycles (not advised)
        p << (options[:cycles] * Origen.tester.period_in_ns) if options[:cycles]

        return @clock_period_in_ns if p.empty?
        fail "[Pin Clock] ERROR: Multiple unit declarations for #{@owner.name}.clock" if p.size > 1

        p[0].to_int
      end

      def duty_str
        "#{@cycles_per_duty[0]}/#{@cycles_per_duty[1]}"
      end
    end
  end
end
