RGen.deprecate <<-END
The V93K Tester in RGen core is being moved to a dedicated plugin,
use Testers::V93K from this plugin instead of RGen::Tester::V93K -
http://rgen.freescale.net/testers
END
module RGen
  module Tester
    # Tester model to generate .avc patterns for the Verigy 930000
    #
    # == Basic Usage
    #   $tester = RGen::Tester::V93K.new
    #   $tester.cycle       # Generate a vector
    #
    # Many more methods exist to generate V93K specific micro-code, see below for
    # details.
    #
    # Also note that this class includes the base Tester module and so all methods
    # described there are also available.
    class V93K
      include Tester

      autoload :Generator, 'rgen/tester/v93k/generator'

      # Returns a new J750 instance, normally there would only ever be one of these
      # assigned to the global variable such as $tester by your target:
      #   $tester = J750.new
      def initialize
        @max_repeat_loop = 65_535
        @pat_extension = 'avc'
        @compress = true
        # @support_repeat_previous = true
        @match_entries = 10
        @name = 'v93k'
        @comment_char = '#'
      end

      # Capture the pin data from a vector to the tester.
      #
      # This method uses the Digital Capture feature (Selective mode) of the V93000 to capture
      # the data from the given pins on the previous vector.
      # Note that is does not actually generate a new vector.
      #
      # Note also that any drive cycles on the target pins can also be captured, to avoid this
      # the wavetable should be set up like this to infer a 'D' (Don't Capture) on vectors where
      # the target pin is being used to drive data:
      #
      #   PINS nvm_fail
      #   0  d1:0  r1:D  0
      #   1  d1:1  r1:D  1
      #   2  r1:C  Capt
      #   3  r1:D  NoCapt
      #
      # Sometimes when generating vectors within a loop you may want to apply a capture
      # retrospectively to a previous vector, passing in an offset option will allow you
      # to do this.
      #
      # ==== Examples
      #   $tester.cycle                     # This is the vector you want to capture
      #   $tester.store :pin => pin(:fail)  # This applys the required opcode to the given pins
      #
      #   $tester.cycle                     # This one gets captured
      #   $tester.cycle
      #   $tester.cycle
      #   $tester.store(:pin => pin(:fail), :offset => -2) # Just realized I need to capture that earlier vector
      #
      #   # Capturing multiple pins:
      #   $tester.cycle
      #   $tester.store :pins => [pin(:fail), pin(:done)]
      #
      # Since the V93K store operates on a pin level (rather than vector level as on the J750)
      # equivalent functionality can also be achieved by setting the store attribute of the pin
      # itself prior to calling $tester.cycle.
      # However it is recommended to use the tester API to do the store if cross-compatiblity with
      # other platforms, such as the J750, is required.
      def store(*pins)
        options = pins.last.is_a?(Hash) ? pins.pop : {}
        options = { offset: 0
                  }.merge(options)
        pins = pins.flatten.compact
        if pins.empty?
          fail 'For the V93K you must supply the pins to store/capture'
        end
        pins.each do |pin|
          pin.restore_state do
            pin.capture
            update_vector_pin_val pin, offset: options[:offset]
            last_vector(options[:offset]).dont_compress = true
          end
        end
      end
      alias_method :capture, :store

      # Capture the next vector generated to HRAM
      #
      # This method applys a store vector (stv) opcode to the next vector to be generated,
      # note that is does not actually generate a new vector.
      #
      # On J750 the pins argument is ignored since the tester only supports whole vector capture.
      #
      # @example
      #   $tester.store_next_cycle
      #   $tester.cycle                # This is the vector that will be captured
      def store_next_cycle(*pins)
        options = pins.last.is_a?(Hash) ? pins.pop : {}
        options = {
        }.merge(options)
        pins = pins.flatten.compact
        if pins.empty?
          fail 'For the V93K you must supply the pins to store/capture'
        end
        pins.each { |pin| pin.save; pin.capture }
        # Register this clean up function to be run after the next vector
        # is generated, cool or what!
        preset_next_vector do
          pins.each(&:restore)
        end
      end

      # Start a subroutine.
      #
      # Generates a global subroutine label. Global is used to adhere to the best practice of
      # containing all subroutines in dedicated patterns, e.g. global_subs.atp
      #
      # ==== Examples
      #     $tester.start_subroutine("wait_for_done")
      #     < generate your subroutine vectors here >
      #     $tester.end_subroutine
      def start_subroutine(name)
        local_subroutines << name.to_s.chomp unless local_subroutines.include?(name.to_s.chomp) || @inhibit_vectors
        # name += "_subr" unless name =~ /sub/
        Pattern.open name: name, call_startup_callbacks: false
      end

      # Ends the current subroutine that was started with a previous call to start_subroutine
      def end_subroutine(_cond = false)
        Pattern.close call_shutdown_callbacks: false
      end

      # Call a subroutine.
      #
      # This calls a subroutine immediately following previous vector, it does not
      # generate a new vector.
      #
      # Subroutines should always be called through this method as it ensures a running
      # log of called subroutines is maintained and which then gets output in the pattern
      # header to import the right dependencies.
      #
      # An offset option is available to make the call on earlier vectors.
      #
      # Repeated calls to the same subroutine will automatically be compressed unless
      # option :suppress_repeated_calls is supplied and set to false. This means that for
      # the common use case of calling a subroutine to implement an overlay the subroutine
      # can be called for every bit that has the overlay and the pattern will automatically
      # generate correctly.
      #
      # ==== Examples
      #   $tester.call_subroutine("mysub")
      #   $tester.call_subroutine("my_other_sub", :offset => -1)
      def call_subroutine(name, options = {})
        options = {
          offset:                  0,
          suppress_repeated_calls: true
        }.merge(options)
        called_subroutines << name.to_s.chomp unless called_subroutines.include?(name.to_s.chomp) || @inhibit_vectors

        code = "SQPG JSUB #{name};"
        if !options[:suppress_repeated_calls] ||
           last_object != code
          microcode code, offset: (options[:offset] * -1)
        end
      end

      # Handshake with the tester.
      #
      # ==== Examples
      #   $tester.handshake                   # Pass control to the tester for a measurement
      def handshake(options = {})
        options = {
        }.merge(options)
        Pattern.split(options)
      end

      # Do a frequency measure.
      #
      # ==== Examples
      #   $tester.freq_count($top.pin(:d_out))                 # Freq measure on pin "d_out"
      def freq_count(_pin, options = {})
        options = {
        }.merge(options)
        Pattern.split(options)
      end

      # Generates a match loop on up to two pins.
      #
      # This method is not really intended to be called directly, rather you should call
      # via Tester#wait e.g. $tester.wait(:match => true).
      #
      # The timeout should be provided in cycles, however when called via the wait method the
      # time-based helpers (time_in_us, etc) will be converted to cycles for you.
      # The following options are available to tailor the match loop behavior, defaults in
      # parenthesis:
      #
      # * :pin - The pin object to match on (*required*)
      # * :state - The pin state to match on, :low or :high (*required*)
      # * :check_for_fails (false) - Flushes the pipeline and checks for fails prior to the match (to allow binout of fails encountered before the match)
      # * :pin2 (nil) - Optionally supply a second pin to match on
      # * :state2 (nil) - State for the second pin (required if :pin2 is supplied)
      # * :force_fail_on_timeout (true) - Force a vector mis-compare if the match loop times out
      #
      # ==== Examples
      #   $tester.wait(:match => true, :time_in_us => 5000, :pin => $top.pin(:done), :state => :high)
      def match(pin, state, timeout, options = {})
        options = {
          check_for_fails:       false,
          pin2:                  false,
          state2:                false,
          force_fail_on_timeout: true,
          global_loops:          false,
          generate_subroutine:   false,
          force_fail_on_timeout: true
        }.merge(options)

        # Ensure the match pins are don't care by default
        pin.dont_care
        options[:pin2].dont_care if options[:pin2]

        # Single condition loops are simple
        if !options[:pin2]
          # Use the counted match loop (rather than timed) which is recommended in the V93K docs for new applications
          # No pre-match failure handling is required here because the system will cleanly record failure info
          # for this kind of match loop

          cc "for the #{pin.name.upcase} pin to go #{state.to_s.upcase}"
          number_of_loops = (timeout.to_f / 8).ceil
          microcode "SQPG MACT #{number_of_loops};"
          # Strobe the pin for the required state
          state == :low ? pin.expect_lo! : pin.expect_hi!
          pin.dont_care
          # Wait for 7 vectors before re-checking, this keeps the loop to 8 vectors which allows the test results
          # to be reconstructed cleanly if multiple loops are called in a pattern
          microcode 'SQPG MRPT 7;'
          # Not sure if no compression is really required here...
          7.times do
            cycle(dont_compress: true)
          end
          microcode 'SQPG PADDING;'

        else

          # For two pins do something more like the J750 approach where branching based on miscompares is used
          # to keep the loop going
          cc "for the #{pin.name.upcase} pin to go #{state.to_s.upcase}"
          cc "or the #{options[:pin2].name.upcase} pin to go #{options[:state2].to_s.upcase}"

          if options[:check_for_fails]
            cc 'Return preserving existing errors if the pattern has already failed before arriving here'
            cycle(repeat: propagation_delay)
            microcode 'SQPG RETC 1 1;'
          end
          number_of_loops = (timeout.to_f / ((propagation_delay * 2) + 2)).ceil

          loop_vectors number_of_loops do
            # Check pin 1
            cc "Check if #{pin.name.upcase} is #{state.to_s.upcase} yet"
            state == :low ? pin.expect_lo! : pin.expect_hi!
            pin.dont_care
            cc 'Wait for failure to propagate'
            cycle(repeat: propagation_delay)
            cc 'Exit match loop if pin has matched (no error), otherwise clear error and remain in loop'
            microcode 'SQPG RETC 0 0;'

            # Check pin 2
            cc "Check if #{options[:pin2].name.upcase} is #{options[:state2].to_s.upcase} yet"
            options[:state2] == :low ? options[:pin2].expect_lo! : options[:pin2].expect_hi!
            options[:pin2].dont_care
            cc 'Wait for failure to propagate'
            cycle(repeat: propagation_delay)
            cc 'Exit match loop if pin has matched (no error), otherwise clear error and remain in loop'
            microcode 'SQPG RETC 0 0;'
          end

          if options[:force_fail_on_timeout]
            cc 'To get here something has gone wrong, strobe again to force a pattern failure'
            state == :low ? pin.expect_lo : pin.expect_hi
            options[:state2] == :low ? options[:pin2].expect_lo : options[:pin2].expect_hi if options[:pin2]
            cycle
            pin.dont_care
            options[:pin2].dont_care if options[:pin2]
          end
          microcode 'SQPG RSUB;'

        end
      end

      # Returns the number of cycles to wait for any fails to propagate through the pipeline based on
      # the current timeset
      def propagation_delay
        # From 'Calculating the buffer cycles for JMPE and RETC (and match loops)' in SmarTest docs
        data_queue_buffer = (([105, 64 + ((125 + current_period_in_ns - 1) / current_period_in_ns).ceil].min + 3) * 8) + 72
        # Don't know how to calculate at runtime, hardcoding these to some default values for now
        number_of_sites = 128
        sclk_period = 40
        prop_delay_buffer = 195 + ((2 * number_of_sites + 3) * (sclk_period / 2))
        data_queue_buffer + prop_delay_buffer
      end

      # Add a loop to the pattern.
      #
      # Pass in the number of times to execute it, all vectors
      # generated by the given block will be captured in the loop.
      #
      # ==== Examples
      #   $tester.loop_vectors 3 do   # Do this 3 times...
      #       $tester.cycle
      #       some_other_method_to_generate_vectors
      #   end
      #
      # For compatibility with the J750 you can supply a name as the first argument
      # and that will simply be ignored when generated for the V93K tester...
      #
      #   $tester.loop_vectors "my_loop", 3 do   # Do this 3 times...
      #       $tester.cycle
      #       some_other_method_to_generate_vectors
      #   end
      def loop_vectors(name = nil, number_of_loops = 1, _global = false)
        # The name argument is present to maych J750 API, sort out the
        unless name.is_a?(String)
          name, number_of_loops, global = nil, name, number_of_loops
        end
        if number_of_loops > 1
          microcode "SQPG LBGN #{number_of_loops};"
          yield
          microcode 'SQPG LEND;'
        else
          yield
        end
      end
      alias_method :loop_vector, :loop_vectors

      # An internal method called by RGen to create the pattern header
      def pattern_header(options = {})
        options = {
        }.merge(options)
        pin_list = ordered_pins.map do |p|
          if RGen.app.pin_pattern_order.include?(p.id)
            p.id # specified name overrides pin name
          else
            p.name
          end
        end.join(' ')
        microcode "FORMAT #{pin_list};"
        max_pin_name_length = ordered_pins.map(&:name).max { |a, b| a.length <=> b.length }.length
        pin_widths = ordered_pins.map { |p| p.size - 1 }

        max_pin_name_length.times do |i|
          cc((' ' * 50) + ordered_pins.map.with_index { |p, x| ((p.name[i] || ' ') + ' ' * pin_widths[x]).gsub('_', '-') }.join(' '))
        end
      end

      # An internal method called by RGen to generate the pattern footer
      def pattern_footer(_options = {})
        microcode 'SQPG STOP;'
      end

      # Returns an array of subroutines called while generating the current pattern
      def called_subroutines
        @called_subroutines ||= []
      end

      # Returns an array of subroutines created by the current pattern
      def local_subroutines # :nodoc:
        @local_subroutines ||= []
      end

      # This is an internal method use by RGen which returns a fully formatted vector
      # You can override this if you wish to change the output formatting at vector level
      def format_vector(vec)
        timeset = vec.timeset ? "#{vec.timeset.name}" : ''
        pin_vals = vec.pin_vals ? "#{vec.pin_vals} ;" : ''
        if vec.repeat # > 1
          microcode = "R#{vec.repeat}"
        else
          microcode = vec.microcode ? vec.microcode : ''
        end
        # if vec.pin_vals && vec.number && vec.cycle_number
        #  comment = " // Vector #{@pattern_vectors}, Cycle #{@pattern_cycles}"
        # else
        comment = ''
        # end
        "#{microcode.ljust(25)} #{timeset.ljust(25)} #{pin_vals} #{comment}"
      end

      # All vectors generated with the supplied block will have all pins set
      # to the repeat previous state. Any pins that are changed state within
      # the block will still update to the supplied value.
      # ==== Example
      #   # All pins except invoke will be assigned the repeat previous code
      #   # in the generated vector. On completion of the block they will
      #   # return to their previous state, except for invoke which will
      #   # retain the value assigned within the block.
      #   $tester.repeat_previous do
      #       $top.pin(:invoke).drive(1)
      #       $tester.cycle
      #   end
      def repeat_previous
        RGen.app.pin_map.each { |_id, pin| pin.repeat_previous = true }
        yield
        RGen.app.pin_map.each { |_id, pin| pin.repeat_previous = false }
      end

      def before_timeset_change(options = {})
        microcode "SQPG CTIM #{options[:new].name};"
      end

      def v93k?
        true
      end
    end
  end
end
