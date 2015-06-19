module RGen
  module Pins
    class Port
      attr_accessor :name
      attr_reader :id
      attr_reader :owner
      attr_reader :size
      attr_accessor :order

      include Pins

      def initialize(id, owner, options = {})
        options = {
          name:     id.to_s,
          endian:   :big,
          add_pins: true
        }.merge(options)
        @endian = options.delete(:endian)
        @size = options.delete(:size)
        @name = options.delete(:name)
        @order = options.delete(:order)
        @id = id
        @owner = owner
        add_pins(options) if options[:add_pins]
      end

      def name
        (RGen.app.pin_names[id] || @name).to_s
      end

      def inspect
        "<#{self.class}:#{object_id}>"
      end

      def add_pins(options)
        size.times do |i|
          ix = @endian == :big ? @size - i - 1 : i
          pin = add_pin(ix, options)
          pin.port = self
        end
      end

      def cycle # :nodoc:
        RGen.tester.cycle
      end

      def drive_mem
        pins.each { |_ix, pin| pin.drive_mem }
      end

      def drive_mem!
        drive_mem
        cycle
      end

      def expect_mem
        pins.each { |_ix, pin| pin.expect_mem }
      end

      def expect_mem!
        expect_mem
        cycle
      end

      # Set the pin to drive a 1 on future cycles
      def drive_hi
        pins.each { |_ix, pin| pin.drive_hi }
      end

      def drive_hi!
        drive_hi
        cycle
      end

      # Set the pin to drive a high voltage on future cycles (if the tester supports it).
      # For example on a J750 high-voltage channel the pin state would be set to "2"
      def drive_very_hi
        pins.each { |_ix, pin| pin.drive_very_hi }
      end

      def drive_very_hi!
        drive_very_hi
        cycle
      end

      # Set the pin to drive a 0 on future cycles
      def drive_lo
        pins.each { |_ix, pin| pin.drive_lo }
      end

      def drive_lo!
        drive_lo
        cycle
      end

      # Set the pin to expect a 1 on future cycles
      def assert_hi(_options = {})
        pins.each { |_ix, pin| pin.assert_hi }
      end
      alias_method :compare_hi, :assert_hi
      alias_method :expect_hi, :assert_hi

      def assert_hi!
        assert_hi
        cycle
      end
      alias_method :compare_hi!, :assert_hi!
      alias_method :expect_hi!, :assert_hi!

      # Set the pin to expect a 0 on future cycles
      def assert_lo(_options = {})
        pins.each { |_ix, pin| pin.assert_lo }
      end
      alias_method :compare_lo, :assert_lo
      alias_method :expect_lo, :assert_lo

      def assert_lo!
        assert_lo
        cycle
      end
      alias_method :compare_lo!, :assert_lo!
      alias_method :expect_lo!, :assert_lo!

      # Set the pin to X on future cycles
      def dont_care
        pins.each { |_ix, pin| pin.dont_care }
      end

      def dont_care!
        dont_care
        cycle
      end

      # Pass in 0 or 1 to have the pin drive_lo or drive_hi respectively.
      # This is useful when programatically setting the pin state.
      # ==== Example
      #   [0,1,1,0].each do |level|
      #       $pin(:d_in).drive(level)
      #   end
      def drive(value)
        size.times do |i|
          pins[i].drive(value[i])
        end
      end

      def drive!(value)
        drive(value)
        cycle
      end

      # Pass in 0 or 1 to have the pin expect_lo or expect_hi respectively.
      # This is useful when programatically setting the pin state.
      # ==== Example
      #   [0,1,1,0].each do |level|
      #       $pin(:d_in).assert(level)
      #   end
      def assert(value, _options = {})
        size.times do |i|
          pins[i].expect(value[i])
        end
      end
      alias_method :compare, :assert
      alias_method :expect, :assert

      def assert!(*args)
        assert(*args)
        cycle
      end

      def [](ix)
        pins[ix]
      end

      # Returns the data value currently assigned to the port
      def data
        d = 0
        size.times do |i|
          d |= pins[i].data << i
        end
        d
      end
      alias_method :value, :data

      # Returns the inverse of the data value currently assigned to the port
      def data_b
        # (& operation takes care of Bignum formatting issues)
        ~data & ((1 << size) - 1)
      end
      alias_method :value_b, :data_b

      # Set the data assigned to the port
      def data=(val)
        size.times do |i|
          pins[i].data = val[i]
        end
      end

      def toggle
        self.data = data_b
      end

      def toggle!
        toggle
        cycle
      end

      def comparing?
        pins.any? { |_ix, pin| pin.comparing? }
      end

      def comparing_mem?
        pins.any? { |_ix, pin| pin.comparing_mem? }
      end

      def driving?
        pins.any? { |_ix, pin| pin.driving? }
      end

      def driving_mem?
        pins.any? { |_ix, pin| pin.driving_mem? }
      end

      def high_voltage?
        pins.any? { |_ix, pin| pin.high_voltage? }
      end

      def repeat_previous=(bool)
        pins.each { |_ix, pin| pin.repeat_previous = bool }
      end

      # Mark the (data) from the port to be captured
      def capture
        pins.each { |_ix, pin| pin.capture }
      end
      alias_method :store, :capture

      # Mark the (data) from the port to be captured and trigger a cycle
      def capture!
        capture
        cycle
      end
      alias_method :store!, :capture!

      # Returns true if the (data) from the port is marked to be captured
      def to_be_captured?
        pins.any? { |_ix, pin| pin.to_be_captured? }
      end
      alias_method :to_be_stored?, :to_be_captured?
      alias_method :is_to_be_stored?, :to_be_captured?
      alias_method :is_to_be_captured?, :to_be_captured?

      # Restores the state of the port at the end of the given block
      # to the state it was in at the start of the block
      #
      #   port(:a).driving?  # => true
      #   port(:a).restore_state do
      #     port(:a).dont_care
      #     port(:a).driving?  # => false
      #   end
      #   port(:a).driving?  # => true
      def restore_state
        pins.each { |_ix, pin| pin.save }
        yield
        pins.each { |_ix, pin| pin.restore }
      end
    end
  end
end
