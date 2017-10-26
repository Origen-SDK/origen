module Origen
  module Registers
    # This is a regular Ruby array that is used to store collections of Bit objects, it has additional
    # methods added to allow interaction with the contained bits.
    # All Ruby array methods are also available - http://www.ruby-doc.org/core/classes/Array.html
    #
    # A BitCollection is returned whenever a subset of bits is requested from a register. Also whenever
    # any of these methods are called on a register object a BitCollection is created on the fly that
    # contains all bits in the register. This means that when interacting with a Register, a single Bit,
    # or a group of Bit objects, the same API can be used as described below.
    class BitCollection < Array
      include Origen::SubBlocks::Path
      include Netlist::Connectable

      DONT_CARE_CHAR = 'X'
      OVERLAY_CHAR = 'V'
      STORE_CHAR = 'S'

      attr_accessor :name
      alias_method :id, :name

      def initialize(reg, name, data = []) # :nodoc:
        if reg.respond_to?(:has_bits_enabled_by_feature?) && reg.has_parameter_bound_bits?
          reg.update_bound_bits unless reg.updating_bound_bits?
        end
        @reg = reg
        @name = name
        [data].flatten.each { |item| self << item }
      end

      # Returns the bit order of the parent register
      def bit_order
        parent.bit_order
      end

      def terminal?
        true
      end

      def bind(live_parameter)
        parent.bind(name, live_parameter)
      end

      def [](*indexes)
        return self if indexes.empty?
        b = BitCollection.new(parent, name)
        expand_and_order(*indexes).each do |i|
          b << fetch(i)
        end
        # When 1 bit requested just return that bit, this is consistent with the original
        # behaviour before sub collections were added
        if b.size == 1
          b.first
        else
          b
        end
      end
      alias_method :bits, :[]
      alias_method :bit, :[]

      def parent
        @reg
      end

      def path_var
        if first.path_var
          if first.path_var =~ /^\./
            base = parent.path(relative_to: parent.parent)
            "#{base}#{first.path_var}"
          else
            first.path_var
          end
        else
          base = parent.path(relative_to: parent.parent)
          if size == 1
            "#{base}[#{position}]"
          else
            "#{base}[#{position + size - 1}:#{position}]"
          end
        end
      end

      def abs_path
        first.abs_path
      end

      Bit::ACCESS_CODES.each do |code, _meta|
        define_method "#{code}?" do
          all? { |b| b.undefined? || b.send("#{code}?") }
        end
      end

      # Update the register contents with the live value from the device under test.
      #
      # The current tester needs to be an OrigenLink driver. Upon calling this method a request will
      # be made to read the given register, the read data will be captured and the register model
      # will be updated.
      #
      # The register parent register object is returned, this means that calling .sync on a register
      # or bitcollection object will automatically update it and the display the register in the
      # console.
      #
      # Normally this method should be called from a breakpoint during pattern debug, and it is
      # not intended to be inserted into production pattern logic.
      def sync(size = nil, options = {})
        size, options = nil, size if size.is_a?(Hash)
        if tester.respond_to?(:capture)
          preserve_flags do
            v = tester.capture do
              store!(sync: true)
            end
            reverse_shift_out_with_index do |bit, i|
              bit.instance_variable_set('@updated_post_reset', true)
              bit.instance_variable_set('@data', v.first[i])
            end
          end
          if size
            puts "#{parent.address.to_s(16).upcase}: " + data.to_s(16).upcase.rjust(Origen.top_level.memory_width / 4, '0')
            if size > 1
              step = Origen.top_level.memory_width / 8
              Origen.top_level.mem(parent.address + step).sync(size - 1)
            end
            nil
          else
            parent
          end
        else
          Origen.log.warning 'Sync is not supported on the current tester driver, register not updated'
        end
      end
      alias_method :sync!, :sync

      # At the end of the given block, the status flags of all bits will be restored to the state that
      # they were upon entry to the block
      def preserve_flags
        orig = []
        each do |bit|
          orig << [bit.overlay_str, bit.is_to_be_read?, bit.is_to_be_stored?]
        end
        yield
        each do |bit|
          bit.clear_flags
          flags = orig.shift
          bit.overlay(flags[0])
          bit.read if flags[1]
          bit.store if flags[2]
        end
        self
      end

      # Copies all data and flags from one bit collection (or reg) object to another
      #
      # This method will accept a dumb value as the argument, in which case it is essentially a write,
      # however it will also clear all flags.
      def copy_all(reg)
        if reg.respond_to?(:contains_bits?) && reg.contains_bits?
          unless reg.size == size
            puts 'Bit collection copy must be performed on collections of the same size.'
            puts 'You can fix this by calling copy on a subset of the bits you require, e.g.'
            puts '  larger_bit_collection[3..0].copy_all(smaller_bit_collection)'
            puts
            fail 'Mismatched size for bit collection copy'
          end
          size.times do |i|
            source_bit = reg.bit[i]
            if source_bit
              self[i].overlay(source_bit.overlay_str) if source_bit.has_overlay?
              self[i].write(source_bit.data)

              self[i].read if source_bit.is_to_be_read?
              self[i].store if source_bit.is_to_be_stored?
            end
          end
        else
          write(reg)
          clear_flags
        end
        self
      end

      # Returns the access attribute of the first contained bit, in most normal use cases
      # the application will naturally guarantee that when this is called all of the bits
      # in the collection have the same access value.
      #
      # If you are worried about hitting the case where some bits have different values then
      # use access!, but this will be a bit less efficient
      def access(value = nil)
        if value.nil?
          first.access
        else # set access
          each { |b| b.set_access(value) }
          self
        end
      end

      # Like access but will raise an error if not all bits in the collection have the same
      # access value
      def access!
        val = access
        if any? { |b| b.access != val }
          fail 'Not all bits the collection have the same access value!'
        end
        val
      end

      # Returns the description of the given bit(s) if any, if none then an empty array
      # will be returned
      #
      # **Note** Adding a description field will override any comment-driven documentation
      # of a bit collection (ie markdown style comments)
      def description(bitname = nil, options = {})
        bitname, options = nil, bitname if bitname.is_a?(Hash)
        if name == :unknown
          []
        else
          @reg.description(name, options)
        end
      end

      def full_name(bitname = nil, options = {})
        bitname, options = nil, bitname if bitname.is_a?(Hash)
        unless name == :unknown
          @reg.full_name(name, options)
        end
      end

      def bit_value_descriptions(_bitname = nil)
        options = _bitname.is_a?(Hash) ? _bitname : {}
        if name == :unknown
          []
        else
          @reg.bit_value_descriptions(name, options)
        end
      end

      # Returns a dummy bit collection that is populated with un-writable bits that will
      # read back as 0. This can be useful for padding out spaces in registers with something that
      # responds like conventional bits.
      def self.dummy(reg, name = nil, options = {})
        name, options = nil, name if name.is_a?(Hash)
        options = {
          size: 8,
          pos:  0
        }.merge(options)
        collection = new(reg, name)
        pos = options[:pos]
        options[:size].times do
          bit = Bit.new(reg, pos, writable: false, feature: :dummy_feature)
          collection << bit
          pos += 1
        end
        collection
      end

      def contains_bits?
        true
      end

      def inspect
        "<#{self.class}:#{object_id}>"
      end

      # Returns the LSB position of the collection
      def position
        first.position
      end

      # Returns the data value held by the collection
      # ==== Example
      #   reg(:control).write(0x55)
      #   reg(:control).data         #  => 0x55, assuming the reg has the required bits to store that
      def data
        data = 0
        shift_out_with_index do |bit, i|
          return undefined if bit.is_a?(Origen::UndefinedClass)
          data |= bit.data << i
        end
        data
      end
      alias_method :val, :data
      alias_method :value, :data

      # Returns the inverse of the data value held by the collection
      def data_b
        # (& operation takes care of Bignum formatting issues)
        ~data & ((1 << size) - 1)
      end

      # Returns the reverse of the data value held by the collection
      def data_reverse
        data = 0
        reverse_shift_out_with_index do |bit, i|
          return undefined if bit.is_a?(Origen::UndefinedClass)
          data |= bit.data << i
        end
        data
      end
      alias_method :reverse_data, :data_reverse

      # Supports reg.bit[0] and bitcollection.bit[0]
      def bit
        self
      end

      # Returns true if the collection contains all bits in the register
      def whole_reg?
        size == parent.size
      end

      # Set the data value of the collection within the patgen, but not on silicon - i.e. calling
      # write will not trigger a pattern write event.
      def write(value, options = {})
        # If an array is written it means a data value and an overlay have been supplied
        # in one go...
        if value.is_a?(Array) && !value.is_a?(BitCollection)
          overlay(value[1])
          value = value[0]
        end
        value = value.data if value.respond_to?('data')

        size.times do |i|
          self[i].write(value[i], options)
        end
        self
      end
      alias_method :data=, :write
      alias_method :value=, :write
      alias_method :val=, :write

      # Will tag all bits for read and if a data value is supplied it
      # will update the expected data for when the read is performed.
      def read(value = nil, options = {}) # :nodoc:
        # First properly assign the args if value is absent...
        if value.is_a?(Hash)
          options = value
          value = nil
        end
        if value
          value = Reg.clean_value(value)
          write(value, force: true)
        end
        if options[:mask]
          shift_out_with_index { |bit, i| bit.read if options[:mask][i] == 1 }
          shift_out_with_index { |bit, i| bit.clear_read_flag if options[:mask][i] == 0 }
        else
          each(&:read)
        end
        self
      end
      alias_method :assert, :read

      # Returns a value representing the bit collection / register where a bit value of
      # 1 means the bit is enabled for the given operation.
      def enable_mask(operation)
        str = ''
        shift_out_left do |bit|
          if operation == :store && bit.is_to_be_stored? ||
             operation == :read && bit.is_to_be_read? ||
             operation == :overlay && bit.has_overlay?
            str += '1'
          else
            str += '0'
          end
        end
        str.to_i(2)
      end

      # Attaches the supplied overlay string to all bits
      # ==== Example
      # reg(:data).overlay("data_val")
      def overlay(value)
        each { |bit| bit.overlay(value) }
        self
      end

      # Resets all bits, this clears all flags and assigns the data value
      # back to the reset state
      def reset
        each(&:reset)
        self
      end

      # Shifts out a stream of bit objects corresponding to the size of the BitCollection. i.e. calling
      # this on a 16-bit register this will pass back 16 bit objects.
      # If there are holes in the given register then a dummy bit object will be returned that
      # is not writable and which will always read as 0.
      # ==== Example
      #   reg(:data).shift_out_left do |bit|
      #       bist_shift(bit)
      #   end
      def shift_out_left
        if bit_order == :msb0
          each { |bit| yield bit }
        else
          reverse_each { |bit| yield bit }
        end
      end

      # Same as Reg#shift_out_left but includes the index counter
      def shift_out_left_with_index
        if bit_order == :msb0
          each.with_index { |bit, i| yield bit, i }
        else
          reverse_each.with_index { |bit, i| yield bit, i }
        end
      end

      # Same as Reg#shift_out_left but starts from the MSB
      def shift_out_right
        if bit_order == :msb0
          reverse_each { |bit| yield bit }
        else
          each { |bit| yield bit }
        end
      end

      # Same as Reg#shift_out_right but includes the index counter
      def shift_out_right_with_index
        if bit_order == :msb0
          reverse_each.with_index { |bit, i| yield bit, i }
        else
          each_with_index { |bit, i| yield bit, i }
        end
      end

      # Yields each bit in the register, LSB first.
      def shift_out(&block)
        each(&block)
      end

      # Yields each bit in the register and its index, LSB first.
      def shift_out_with_index(&block)
        each_with_index(&block)
      end

      # Yields each bit in the register, MSB first.
      def reverse_shift_out(&block)
        reverse_each(&block)
      end

      # Yields each bit in the register and its index, MSB first.
      def reverse_shift_out_with_index(&block)
        reverse_each.with_index(&block)
      end

      # Returns true if any bits have the read flag set - see Bit#is_to_be_read?
      # for more details.
      def is_to_be_read?
        any?(&:is_to_be_read?)
      end

      # Returns true if any bits have the store flag set - see Bit#is_to_be_stored?
      # for more details.
      def is_to_be_stored?
        any?(&:is_to_be_stored?)
      end

      # Returns true if any bits have the update_required flag set - see Bit#update_required?
      # for more details.
      def update_required?
        any?(&:update_required?)
      end

      # Calls the clear_flags method on all bits, see Bit#clear_flags for more details
      def clear_flags
        each(&:clear_flags)
        self
      end

      # Returns the value you would need to write to the register to put the given
      # value in these bits
      def setting(value)
        result = 0
        shift_out_with_index do |bit, i|
          result |= bit.setting(value[i])
        end
        result
      end

      # Returns true if any bits within are tagged for overlay, supply a specific name
      # to require a specific overlay only
      # ==== Example
      #   myreg.overlay("data")
      #   myreg.has_overlay?              # => true
      #   myreg.has_overlay?("address")   # => false
      #   myreg.has_overlay?("data")      # => true
      def has_overlay?(name = nil)
        any? { |bit| bit.has_overlay?(name) }
      end

      # Cycles through all bits and returns the last overlay value found, it is assumed therefore
      # that all bits have the same overlay value when calling this method
      # ==== Example
      #   myreg.overlay("data")
      #
      #   myreg.overlay_str   # => "data"
      def overlay_str
        result = ''
        each do |bit|
          result = bit.overlay_str if bit.has_overlay?
        end
        result.to_s
      end

      # Write the bit value on silicon.
      # This method will update the data value of the bits and then call $top.write_register
      # passing the owning register as the first argument.
      # This method is expected to handle writing the current state of the register to silicon.
      def write!(value = nil, options = {})
        value, options = nil, value if value.is_a?(Hash)
        write(value, options) if value
        if block_given?
          yield size == @reg.size ? @reg : self
        end
        @reg.request(:write_register, options)
        self
      end

      # Similar to write! this method will perform the standard read method and then make
      # a call to $top.read_register(self) with the expectation that this method will
      # implement a read event in the pattern.
      # ==== Example
      #   reg(:data).read!         # Read register :data, expecting whatever value it currently holds
      #   reg(:data).read!(0x5555) # Read register :data, expecting 0x5555
      def read!(value = nil, options = {})
        value, options = nil, value if value.is_a?(Hash)
        read(value, options) unless block_given?
        if block_given?
          yield size == @reg.size ? @reg : self
        end
        @reg.request(:read_register, options)
        self
      end
      alias_method :assert!, :read!

      # Normally whenever a register is processed by the $top.read_register method
      # it will call Reg#clear_flags to acknowledge that the read has been performed,
      # which clears the read and store flags for the given bits. Normally however you
      # want overlays to stick around such that whenever a given bit is written/read its
      # data is always picked from an overlay.<br>
      # Call this passing in false for a given register to cause the overlay data to also
      # be cleared by Reg#clear_flags.
      # ==== Example
      #   reg(:data).overlay("data_val")
      #   reg(:data).has_overlay?           # => true
      #   reg(:data).clear_flags
      #   reg(:data).has_overlay?           # => true
      #   reg(:data).sticky_overlay(false)
      #   reg(:data).clear_flags
      #   reg(:data).has_overlay?           # => false
      def sticky_overlay(set = true)
        each { |bit| bit.sticky_overlay = set }
        self
      end
      alias_method :sticky_overlays, :sticky_overlay

      # Similar to sticky_overlay this method affects how the store flags are treated by
      # Reg#clear_flags.<br>
      # The default is that store flags will get cleared  by Reg#clear_flags, passing true
      # into this method will override this and prevent them from clearing.
      # ==== Example
      #   reg(:data).sticky_store(true)
      #   reg(:data).store
      #   reg(:data).clear_flags         # Does not clear the request to store
      def sticky_store(set = true)
        each { |bit| bit.sticky_store = set }
        self
      end

      # Marks all bits to be stored
      def store(options = {})
        each(&:store)
        self
      end

      # Marks all bits to be stored and then calls read!
      def store!(options = {})
        store(options)
        read!(options)
        self
      end

      # Sets the store flag on all bits that already have the overlay flag set
      # and then calls $top.read_register passing self as the first argument
      def store_overlay_bits!(options = {})
        store_overlay_bits(options)
        @reg.request(:read_register, options) # Bypass the normal read method since we don't want to
        # tag the other bits for read
        self
      end

      # Sets the store flag on all bits that already have the overlay flag set
      def store_overlay_bits(options = {})
        options = { exclude: [],         # Pass in an array of any overlays that are to be excluded from store
                  }.merge(options)
        each do |bit|
          bit.store if bit.has_overlay? && !options[:exclude].include?(bit.overlay_str)
        end
        self
      end

      # Will yield all unique overlay strings attached to the bits within the collection.
      # It will also return the number of bits for the overlay (the length) and the current
      # data value held in those bits.
      # ==== Example
      #   reg(:control).unique_overlays do |str, length, data|
      #       do_something(str, length, data)
      #   end
      def unique_overlays
        current_overlay = false
        length = 0
        data = 0
        shift_out_right do |bit|
          # Init the current overlay when the first one is encountered
          current_overlay = bit.overlay_str if bit.has_overlay? && !current_overlay

          if bit.has_overlay?
            if bit.overlay_str != current_overlay
              yield current_overlay, length, data if current_overlay
              length = 0
              data = 0
            end

            data = data | (bit.data << length)
            length += 1
          else
            yield current_overlay, length, data if current_overlay
            length = 0
            data = 0
            current_overlay = false
          end
        end
        yield current_overlay, length, data if current_overlay
      end

      # Append a value, for example a block identifier, to all overlays
      # ==== Example
      #   reg(:data).overlay("data_val")
      #   reg(:data).append_overlays("_0")
      #   reg(:data).overlay_str           # => "data_val_0"
      def append_overlays(value)
        each do |bit|
          bit.overlay(bit.overlay_str + value) if bit.has_overlay?
        end
        self
      end

      # Delete the contained bits from the parent Register
      def delete
        @reg.delete_bits(self)
        self
      end

      def add_name(name) # :nodoc:
        if @name == :unknown
          @name = name
        elsif ![name].flatten.include?(name)
          @name = [@name, name].flatten
        end
        self
      end

      def owner
        first.owner
      end

      # All other methods send to bit 0
      def method_missing(method, *args, &block) # :nodoc:
        if first.respond_to?(method)
          if size > 1
            if [:meta, :meta_data, :metadata].include?(method.to_sym) ||
               first.meta_data_method?(method)
              first.send(method, *args, &block)
            else
              fail "Error, calling #{method} on a multi-bit collection is not implemented!"
            end
          else
            first.send(method, *args, &block)
          end
        else
          fail "BitCollection does not have a method named #{method}!"
        end
      end

      # Recognize that BitCollection responds to some Bit methods via method_missing
      def respond_to?(*args) # :nodoc:
        sym = args.first
        first.respond_to?(sym) || super(sym)
      end

      # Returns true if the values of all bits in the collection are known. The value will be
      # unknown in cases where the reset value is undefined or determined by a memory location
      # and where the register has not been written or read to a specific value yet.
      def has_known_value?
        all?(&:has_known_value?)
      end

      # Returns the reset value of the collection, note that this does not reset the register and the
      # current data is maintained.
      #
      # ==== Example
      #   reg(:control).write(0x55)
      #   reg(:control).data         #  => 0x55
      #   reg(:control).reset_data   #  => 0x11, assuming the reg was declared with a reset value of 0x11
      #   reg(:control).data         #  => 0x55
      def reset_data(value = nil)
        # This method was originally setup to set the reset value by passing an argument
        if value
          shift_out_with_index { |bit, i| bit.reset_val = value[i] }
          self
        else
          data = 0
          shift_out_with_index do |bit, i|
            return bit.reset_data if bit.reset_data.is_a?(Symbol)
            data |= bit.reset_data << i
          end
          data
        end
      end
      alias_method :reset_val, :reset_data
      alias_method :reset_value, :reset_data
      alias_method :reset_data=, :reset_data
      alias_method :reset_val=, :reset_data
      alias_method :reset_value=, :reset_data

      # Modify writable for bits in collection
      def writable(value)
        shift_out_with_index { |bit, i| bit.writable = (value[i] == 0b1); bit.set_access_from_rw }
        self
      end

      # Modify readable for bits in collection
      def readable(value)
        shift_out_with_index { |bit, i| bit.readable = (value[i] == 0b1); bit.set_access_from_rw }
        self
      end

      def feature
        feature = []
        feature << fetch(0).feature
        each { |bit| feature << bit.feature if bit.has_feature_constraint? }
        feature = feature.flatten.uniq unless feature.empty?
        feature.delete(nil) if feature.include?(nil)
        if !feature.empty?
          if feature.size == 1
            return feature[0]
          else
            return feature.uniq
          end
        else
          if Origen.config.strict_errors
            fail 'No feature found'
          end
          return nil
        end
      end
      alias_method :features, :feature

      # Return true if there is any feature associated with these bits
      def has_feature_constraint?(name = nil)
        if !name
          any?(&:has_feature_constraint?)
        else
          any? { |bit| bit.enabled_by_feature?(name) }
        end
      end
      alias_method :enabled_by_feature?, :has_feature_constraint?

      def enabled?
        all?(&:enabled?)
      end

      # Returns true if any bits in the collection are writable
      def is_writable?
        any?(&:writable?)
      end
      alias_method :writable?, :is_writable?

      # Returns true if any bits in the collection are readable
      def is_readable?
        any?(&:readable?)
      end
      alias_method :readable?, :is_readable?

      # Modify clr_only for bits in collection
      def clr_only(value)
        shift_out_with_index { |bit, i| bit.clr_only = (value[i] == 0b1) }
        self
      end

      # Modify set_only for bits in collection
      def set_only(value)
        shift_out_with_index { |bit, i| bit.set_only = (value[i] == 0b1) }
        self
      end

      # Return nvm_dep value held by collection
      def nvm_dep
        nvm_dep = 0
        shift_out_with_index { |bit, i| nvm_dep |= bit.nvm_dep << i }
        nvm_dep
      end

      # Clear any w1c set bits back to 0
      def clear_w1c
        each(&:clear_w1c)
        self
      end

      # Clear any start set bits back to 0
      def clear_start
        each(&:clear_start)
        self
      end

      # Provides a string summary of the bit collection / register state that would be
      # applied to given operation (write or read).
      # This is mainly intended to be useful when generating pattern comments describing
      # an upcoming register transaction.
      #
      # This highlights not only bit values bit the status of any flags or overlays that
      # are currently set.
      #
      # The data is presented in hex nibble format with individual nibbles are expanded to
      # binary format whenever all 4 bits do not have the same status - e.g. if only one
      # of the four is marked for read.
      #
      # The following symbols are used to represent bit state:
      #
      # X - Bit is don't care (not marked for read)
      # V - Bit has been tagged with an overlay
      # S - Bit is marked for store
      #
      # @example
      #
      #   myreg.status_str(:write)   # => "0000"
      #   myreg.status_str(:read)    # => "XXXX"
      #   myreg[7..4].read(5)
      #   myreg.status_str(:read)    # => "XX5X"
      #   myreg[14].read(0)
      #   myreg.status_str(:read)    # => "(x0xx)X5X"
      def status_str(operation, options = {})
        options = {
          mark_overlays: true
        }.merge(options)
        str = ''
        if operation == :read
          shift_out_left do |bit|
            if bit.is_to_be_stored?
              str += STORE_CHAR
            elsif bit.is_to_be_read?
              if bit.has_overlay? && options[:mark_overlays]
                str += OVERLAY_CHAR
              else
                str += bit.data.to_s
              end
            else
              str += DONT_CARE_CHAR
            end
          end
        elsif operation == :write
          shift_out_left do |bit|
            if bit.has_overlay? && options[:mark_overlays]
              str += OVERLAY_CHAR
            else
              str += bit.data.to_s
            end
          end
        else
          fail "Unknown operation (#{operation}), must be :read or :write"
        end
        make_hex_like(str, size / 4)
      end

      # Shifts the data in the collection left by one place. The data held
      # by the rightmost bit will be set to the given value (0 by default).
      #
      # @example
      #   myreg.data          # => 0b1111
      #   myreg.shift_left
      #   myreg.data          # => 0b1110
      #   myreg.shift_left
      #   myreg.data          # => 0b1100
      #   myreg.shift_left(1)
      #   myreg.data          # => 0b1001
      #   myreg.shift_left(1)
      #   myreg.data          # => 0b0011
      def shift_left(data = 0)
        prev_bit = nil
        reverse_shift_out do |bit|
          prev_bit.write(bit.data) if prev_bit
          prev_bit = bit
        end
        prev_bit.write(data)
        self
      end

      # Shifts the data in the collection right by one place. The data held
      # by the leftmost bit will be set to the given value (0 by default).
      #
      # @example
      #   myreg.data          # => 0b1111
      #   myreg.shift_right
      #   myreg.data          # => 0b0111
      #   myreg.shift_right
      #   myreg.data          # => 0b0011
      #   myreg.shift_right(1)
      #   myreg.data          # => 0b1001
      #   myreg.shift_right(1)
      #   myreg.data          # => 0b1100
      def shift_right(data = 0)
        prev_bit = nil
        shift_out do |bit|
          prev_bit.write(bit.data) if prev_bit
          prev_bit = bit
        end
        prev_bit.write(data)
        self
      end

      private

      # Converts a binary-like representation of a data value into a hex-like version.
      # e.g. input  => 010S0011SSSS0110   (where S, X or V represent store, don't care or overlay)
      #      output => (010s)3S6    (i.e. nibbles that are not all of the same type are expanded)
      def make_hex_like(regval, size_in_nibbles)
        outstr = ''
        regex = '^'
        size_in_nibbles.times { regex += '(....)' }
        regex += '$'
        Regexp.new(regex) =~ regval

        nibbles = []
        size_in_nibbles.times do |n|                   # now grouped by nibble
          nibbles << Regexp.last_match[n + 1]
        end

        nibbles.each_with_index do |nibble, i|
          # If contains any special chars...
          if nibble =~ /[#{DONT_CARE_CHAR}#{STORE_CHAR}#{OVERLAY_CHAR}]/
            # If all the same...
            if nibble[0] == nibble[1] && nibble[1] == nibble[2] && nibble[2] == nibble[3]
              outstr += nibble[0, 1] # .to_s
            # Otherwise present this nibble in 'binary' format
            else
              outstr += "(#{nibble.downcase})"
            end
          # Otherwise if all 1s and 0s...
          else
            outstr += '%1X' % nibble.to_i(2)
          end
        end
        outstr
      end

      # Cleans up indexed references to pins, e.g. makes these equal:
      #
      #   bits(:data)[0,1,2,3]
      #   bits(:data)[3,2,1,0]
      #   bits(:data)[0..3]
      #   bits(:data)[3..0]
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
    end
  end
end
