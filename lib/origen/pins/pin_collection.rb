module Origen
  module Pins
    # A class that is used to wrap collections of one or more pins. Anytime a group
    # of pins is fetched or returned by the Pin API it will be wrapped in a PinCollection.
    class PinCollection
      include PinCommon
      include Enumerable

      attr_accessor :endian
      attr_accessor :description

      def initialize(owner, *pins)
        options = pins.last.is_a?(Hash) ? pins.pop : {}
        options = {
          endian: :big
        }.merge(options)
        @power_pins = options.delete(:power_pin) || options.delete(:power_pins)
        @ground_pins = options.delete(:ground_pin) || options.delete(:ground_pins)
        @virtual_pins = options.delete(:virtual_pin) || options.delete(:virtual_pins)
        @other_pins = options.delete(:other_pin) || options.delete(:other_pins)
        @endian = options[:endian]
        @description = options[:description] || options[:desc]
        @options = options
        @store = []
        pins.each_with_index do |pin, i|
          @store[i] = pin
        end
        on_init(owner, options)
      end

      # Returns the value held by the pin group as a string formatted to the current tester's pattern syntax
      #
      # @example
      #
      #   pin_group.drive_hi
      #   pin_group.to_vector   # => "11111111"
      #   pin_group.expect_lo
      #   pin_group.to_vector   # => "LLLLLLLL"
      def to_vector
        return @vector_formatted_value if @vector_formatted_value
        vals = map(&:to_vector)
        vals.reverse! if endian == :little
        @vector_formatted_value = vals.join('')
      end

      # @api private
      def invalidate_vector_cache
        @vector_formatted_value = nil
      end

      # Set the values and states of the pin group's pins from a string formatted to the current tester's pattern syntax,
      # this is the opposite of the to_vector method
      #
      # @example
      #
      #   pin_group.vector_formatted_value = "LLLLLLLL"
      #   pin_group[0].driving?                          # => false
      #   pin_group[0].value                             # => 0
      #   pin_group.vector_formatted_value = "HHHH1111"
      #   pin_group[0].driving?                          # => true
      #   pin_group[0].value                             # => 1
      #   pin_group[7].driving?                          # => false
      #   pin_group[7].value                             # => 1
      def vector_formatted_value=(val)
        unless @vector_formatted_value == val
          unless val.size == size
            fail 'When setting vector_formatted_value on a pin group you must supply values for all pins!'
          end
          val.split(//).reverse.each_with_index do |val, i|
            self[i].vector_formatted_value = val
          end
          @vector_formatted_value = val
        end
      end

      # Returns true if the pin collection contains power pins rather than regular pins
      def power_pins?
        @power_pins
      end

      # Returns true if the pin collection contains ground pins rather than regular pins
      def ground_pins?
        @ground_pins
      end

      # Returns true if the pin collection contains virtual pins rather than regular pins
      def virtual_pins?
        @virtual_pins
      end

      # Returns true if the pin collection contains other pins rather than regular pins
      def other_pins?
        @other_pins
      end

      def id
        @id
      end

      # Explicitly set the name of a pin group/collection
      def name=(val)
        @name = val
      end

      def name
        @name || id
      end

      # Overrides the regular Ruby array each to be endian aware. If the pin collection/group is
      # defined as big endian then this will yield the least significant pin first, otherwise for
      # little endian the most significant pin will come out first.
      def each
        size.times do |i|
          if endian == :big
            yield @store[size - i - 1]
          else
            yield @store[i]
          end
        end
      end

      def size
        @store.size
      end

      def [](*indexes)
        if indexes.size > 1 || indexes.first.is_a?(Range)
          p = PinCollection.new(owner, @options)
          expand_and_order(indexes).each do |index|
            p << @store[index]
          end
          p
        else
          @store[indexes.first]
        end
      end

      def sort!(&block)
        @store = sort(&block)
        self
      end

      def sort_by!
        @store = sort_by
        self
      end

      def []=(index, pin)
        @store[index] = pin
      end

      # Describe the pin group contents.  Default is to display pin.id but passing in
      # :name will display pin.name
      def describe(display = :id)
        desc = ['********************']
        desc << "Group id: #{id}"
        desc << "\nDescription: #{description}" if description
        desc << "\nEndianness: #{endian}"

        unless size == 0
          desc << ''
          desc << 'Pins'
          desc << '-------'
          if display == :id
            desc << map(&:id).join(', ')
          elsif display == :name
            desc << map(&:name).join(', ')
          else
            fail 'Error: Argument options for describe method are :id and :name.  Default is :id'
          end
        end

        desc << '********************'
        puts desc.join("\n")
      end

      def add_pin(pin, _options = {})
        if pin.is_a?(PinCollection)
          # Need this to bypass the endianness aware iteration, the storing order
          # is always the same. So can't use each and co here.
          pin.size.times do |i|
            pin[i].invalidate_group_cache
            @store.push(pin[i])
          end
        else
          # Convert any named reference to a pin object
          if power_pins?
            pin = owner.power_pins(pin)
          elsif ground_pins?
            pin = owner.ground_pins(pin)
          elsif other_pins?
            pin = owner.other_pins(pin)
          elsif virtual_pins?
            pin = owner.virtual_pins(pin)
          else
            pin = owner.pins(pin)
          end
          if @store.include?(pin)
            fail "Pin collection #{id} already contains pin #{pin.id}!"
          else
            pin.invalidate_group_cache
            @store.push(pin)
          end
        end
      end
      alias_method :<<, :add_pin

      def drive(val)
        val = val.data if val.respond_to?('data')
        each_with_index do |pin, i|
          pin.drive(val[size - i - 1])
        end
        self
      end

      def drive!(val)
        drive(val)
        cycle
      end

      # Set all pins in pin group to drive 1's on future cycles
      def drive_hi
        each(&:drive_hi)
        self
      end

      def drive_hi!
        drive_hi
        cycle
      end

      # Set all pins in pin group to drive 0's on future cycles
      def drive_lo
        each(&:drive_lo)
        self
      end

      def drive_lo!
        drive_lo
        cycle
      end

      # Set all pins in the pin group to drive a high voltage on future cycles (if the tester supports it).
      # For example on a J750 high-voltage channel the pin state would be set to "2"
      def drive_very_hi
        each(&:drive_very_hi)
        self
      end

      def drive_very_hi!
        drive_very_hi
        cycle
      end

      def drive_mem
        each(&:drive_mem)
        self
      end

      def drive_mem!
        drive_mem
        cycle
      end

      def expect_mem
        each(&:expect_mem)
        self
      end

      def expect_mem!
        expect_mem
        cycle
      end

      # Returns the data value held by the collection
      # ==== Example
      #   pins(:porta).write(0x55)
      #   pins(:porta).data         #  => 0x55
      def data
        data = 0
        each_with_index { |pin, i| data |= pin.data << (size - i - 1) }
        data
      end
      alias_method :val, :data
      alias_method :value, :data

      # Returns the inverse of the data value held by the collection
      def data_b
        # (& operation takes care of Bignum formatting issues)
        ~data & ((1 << size) - 1)
      end

      def toggle
        each(&:toggle)
        self
      end

      def toggle!
        toggle
        cycle
      end

      def repeat_previous=(bool)
        each { |pin| pin.repeat_previous = bool }
        self
      end

      # Mark the (data) from all the pins in the pin group to be captured
      def capture
        each(&:capture)
        self
      end
      alias_method :store, :capture

      def capture!
        capture
        cycle
      end
      alias_method :store!, :capture!

      def restore_state
        each(&:save)
        yield
        each(&:restore)
      end

      def id=(val)
        @id = val.to_sym
      end

      def cycle
        Origen.tester.cycle
      end

      def assert(value, options = {})
        each_with_index do |pin, i|
          if !value.respond_to?('data')
            pin.assert(value[size - i - 1], options)
          elsif value[size - i - 1].is_to_be_read?
            pin.assert(value[size - i - 1].data, options)
          else
            pin.dont_care
          end
        end
        self
      end
      alias_method :compare, :assert
      alias_method :expect, :assert

      def assert!(*args)
        assert(*args)
        cycle
      end
      alias_method :compare!, :assert!
      alias_method :expect!, :assert!

      # Set all pins in the pin group to expect 1's on future cycles
      def assert_hi(options = {})
        each { |pin| pin.assert_hi(options) }
        self
      end
      alias_method :expect_hi, :assert_hi
      alias_method :compare_hi, :assert_hi

      def assert_hi!
        assert_hi
        cycle
      end
      alias_method :expect_hi!, :assert_hi!
      alias_method :compare_hi!, :assert_hi!

      # Set all pins in the pin group to expect 0's on future cycles
      def assert_lo(options = {})
        each { |pin| pin.assert_lo(options) }
        self
      end
      alias_method :expect_lo, :assert_lo
      alias_method :compare_lo, :assert_lo

      def assert_lo!
        assert_lo
        cycle
      end
      alias_method :expect_lo!, :assert_lo!
      alias_method :compare_lo!, :assert_lo!

      # Set all pins in the pin group to X on future cycles
      def dont_care
        each(&:dont_care)
        self
      end

      def dont_care!
        dont_care
        cycle
      end

      def inverted?
        all?(&:inverted?)
      end

      def comparing?
        all?(&:comparing?)
      end

      def comparing_mem?
        all?(&:comparing_mem?)
      end

      def driving?
        all?(&:driving?)
      end

      def driving_mem?
        all?(&:driving_mem?)
      end

      def high_voltage?
        all?(&:high_voltage?)
      end

      def repeat_previous?
        all?(&:repeat_previous?)
      end

      # Returns true if the (data) from the pin collection is marked to be captured
      def to_be_captured?
        all?(&:to_be_captured?)
      end
      alias_method :to_be_stored?, :to_be_captured?
      alias_method :is_to_be_stored?, :to_be_captured?
      alias_method :is_to_be_captured?, :to_be_captured?

      # Deletes all occurrences of a pin in a pin group
      def delete(p)
        @store.delete(p)
      end

      # Deletes the pin at a particular numeric index within the pin group
      def delete_at(index)
        @store.delete_at(index)
      end

      def pins(nick = :id)
        Origen.deprecate <<-END
The PinCollection#pins method is deprecated, if you want to get a list of pin IDs
in the given collection just do pins(:some_group).map(&:id)
Note that the pins method (confusingly) also does a sort, to replicate that:
pins(:some_group).map(&:id).sort
        END
        if nick == :id
          @store.map(&:id).sort
        elsif nick == :name
          @store.map(&:name).sort
        end
      end

      # Delete this pingroup (self)
      def delete!
        owner.delete_pin(self)
      end

      private

      # Cleans up indexed references to pins, e.g. makes these equal:
      #
      #   pins(:pb)[0,1,2,3]
      #   pins(:pb)[3,2,1,0]
      #   pins(:pb)[0..3]
      #   pins(:pb)[3..0]
      def expand_and_order(*indexes)
        ixs = []
        indexes.flatten.each do |index|
          if index.is_a?(Range)
            if index.first > index.last
              ixs << (index.last..index.first).to_a
            else
              ixs << index.to_a
            end
          else
            ixs << index
          end
        end
        ixs.flatten.sort
      end

      def method_missing(method, *args, &block)
        # Where the collection is only comprised of one pin delegate missing methods/attributes
        # to that pin
        if size == 1
          first.send(method, *args, &block)
        # Send all assignment methods to all contained pins
        elsif method.to_s =~ /.*=$/
          each do |pin|
            pin.send(method, *args, &block)
          end
        else
          if block_given?
            fail 'Blocks are not currently supported by pin collections containing multiple pins!'
          else
            # Allow getters if all pins are the same
            ref = first.send(method, *args)
            if self.all? { |pin| pin.send(method, *args) == ref }
              ref
            else
              fail "The pins held by pin collection #{id} have different values for #{method}"
            end
          end
        end
      end
    end
  end
end
