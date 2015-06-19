module RGen
  module Registers
    # A container can be used to easily interface register operations to an IPS-style
    # interface where the container will take care of data alignment and byte enable
    # calculations.
    # A container looks and behaves like a register and drivers should be able to
    # accept a container in place of a regular register.
    #
    # Here are some examples:
    #
    #     include RGen::Registers
    #
    #     #       Name  Address  Size  Bits
    #     add_reg :r0,   4,       8,    data => {:bits => 8}
    #     add_reg :r1,   5,       8,    data => {:bits => 8}
    #     add_reg :r2,   6,       8,    data => {:bits => 8}
    #     add_reg :r3,   7,       8,    data => {:bits => 8}
    #
    #     reg(:r0).write(0xB0)
    #     reg(:r1).write(0xB1)
    #     reg(:r2).write(0xB2)
    #     reg(:r3).write(0xB3)
    #
    #     big    = Container.new
    #     little = Container.new(:endian => :little)
    #
    #     big.add(reg(:r0)).data              # => 0x0000_00B0
    #     little.add(reg(:r0)).data           # => 0xB000_0000
    #     big.byte_enable                     # => 0b0001
    #     little.byte_enable                  # => 0b1000
    #
    #     big.empty
    #     big.data                            # => 0x0000_0000
    #     big.address                         # => nil
    #     big.add(reg(:r2))
    #     big.address                         # => 4 (longword aligned)
    #     big.add(reg(:r3)).add(reg(:r1)
    #     big.add.data                        # => 0xB3B2_B100
    #     big.byte_enable                     # => 0b1110
    #
    #     # Treat it like it's a register in drivers:
    #     big.shift_out_left do |bit|
    #       pin(:tdi).drive!(bit.data)
    #     end
    #
    #     # The address can be overridden
    #     big.empty
    #     big.add(reg(:r2), :address => 10)
    #     big.address                         # => 8 (longword aligned)
    #
    #     # Containers can accomodate other containers
    #     big.empty
    #     lower_word = Container.new
    #     lower_word.add(:r0).add(:r1)
    #     big.add(:r3)
    #     lower_word.data                     # => 0x0000_B1B0
    #     big.data                            # => 0xB300_0000
    #     big.add(lower_word)
    #     big.data                            # => 0xB300_B1B0
    #     lower_word.data                     # => 0x0000_B1B0
    #
    #     # Contained registers are the same register objects
    #     reg(:r0).write(0x55)
    #     big.data                            # => 0xB300_B155
    #     lower_word.data                     # => 0x0000_B155
    class Container
      # The size of the container in bits
      attr_reader :size
      # The number of bits represented by an address increment
      # of the contained registers. For example if the contained registers
      # have a byte address this will return 8.
      attr_reader :bits_per_address
      # Returns the currently held registers
      attr_reader :regs
      alias_method :registers, :regs
      # Set this to a string or an array of strings that represents the name of the object that owns the
      # container. If present any owned_by? requests made to the container will be
      # evaluated against this string. If not then the request will be sent to the
      # first contained register (if present).
      attr_accessor :owned_by

      # @param [Hash] options Options to customize the container
      # @option options [Integer] :size (32) The size of the container in bits
      # @option options [Symbol] :endian (:big) The endianness of the container, :big or :little
      #   For example big endian means that 4 a 32-bit container the bytes are arranged
      #   [3,2,1,0] whereas a little endian container would be [0,1,2,3].
      # @option options [Integer] :bits_per_address (8) The number of bits that will be represented
      #   by an address increment of the given register's addresses
      def initialize(options = {})
        options = {
          size:             32,
          endian:           :big,
          bits_per_address: 8
        }.merge(options)
        @size = options[:size]
        @endian = options[:endian]
        @owned_by = options[:owned_by]
        @bits_per_address = options[:bits_per_address]
        @regs = []
        @addresses = {}
      end

      def contains_bits?
        true
      end

      # Add the given register to the container, currently there is no
      # error checking performed to ensure that it doesn't overlap with
      # any existing contained registers.
      def add(reg, options = {})
        @regs << reg
        addr = options[:address] || options[:addr]
        @addresses[reg] = addr if addr
        @regs.sort_by! { |reg| address_of_reg(reg) }
        self
      end

      # @api private
      def address_of_reg(reg)
        @addresses[reg] || reg.address
      end

      # Returns the data held by the contained registers where the data from
      # each register is shifted into the correct position
      def data
        d = 0
        regs.each do |reg|
          d += (reg.data << bit_shift_for_reg(reg))
        end
        d
      end
      alias_method :val, :data
      alias_method :value, :data

      # Data bar, the ones complement of the current data value of the
      # container
      def data_b
        ~data & ((1 << size) - 1)
      end

      # Remove all registers from the container
      def empty
        @regs = []
        @addresses = {}
        self
      end

      # Returns the owner of the contained registers (assumed to be the
      # same for all)
      def owner
        unless @regs.empty?
          @regs.first.owner
        end
      end

      # Proxies to the Reg#owned_by? method
      def owned_by?(name)
        if owned_by
          [owned_by].flatten.any? do |al|
            al.to_s =~ /#{name}/i
          end
        else
          if @regs.empty?
            false
          else
            @regs.first.owned_by?(name)
          end
        end
      end

      # Returns the aligned address of the container based on the
      # address of the currently contained registers
      def address
        unless @regs.empty?
          addr = address_of_reg(@regs.first)
          shift = Math.log(size / bits_per_address, 2)
          (addr >> shift) << shift
        end
      end
      alias_method :addr, :address

      # Returns the byte enable required to update the contained registers.
      def byte_enable
        enable = 0
        regs.each do |reg|
          enable_bits = 0.ones_comp(reg.size / bits_per_address)
          enable += (enable_bits << shift_for_reg(reg))
        end
        enable
      end

      # @api private
      def local_addr_for_reg(reg)
        address_of_reg(reg) & 0.ones_comp(Math.log(size / bits_per_address, 2))
      end

      # @api private
      def shift_for_reg(reg)
        if big_endian?
          local_addr_for_reg(reg)
        else
          (size / bits_per_address) - (local_addr_for_reg(reg) + (reg.size / bits_per_address))
        end
      end

      # @api private
      def bit_shift_for_reg(reg)
        shift_for_reg(reg) * bits_per_address
      end

      def big_endian?
        @endian == :big
      end

      def little_endian?
        !big_endian?
      end

      # Shifts out a stream of bit objects corresponding to the size of the container. i.e. calling
      # this on a 32-bit container this will pass back 32 bit objects.
      # If there are holes then a dummy bit object will be returned that
      # is not writable and which will always read as 0.
      #
      # The index is also returned as a second argument. Note that
      # the position property of the bit is not updated to reflect its position
      # within the container (it will return its position with its parent
      # register), therefore the index should be used if the calling code
      # needs to work out the bit position within the container.
      def shift_out_left
        size.times do |i|
          yield(bit_at_position(size - i - 1), i)
        end
      end
      alias_method :shift_out_left_with_index, :shift_out_left

      # Shifts out a stream of bit objects corresponding to the size of the container. i.e. calling
      # this on a 32-bit container this will pass back 32 bit objects.
      # If there are holes then a dummy bit object will be returned that
      # is not writable and which will always read as 0.
      #
      # The index is also returned as a second argument. Note that
      # the position property of the bit is not updated to reflect its position
      # within the container (it will return its position with its parent
      # register), therefore the index should be used if the calling code
      # needs to work out the bit position within the container.
      def shift_out_right
        size.times do |i|
          yield(bit_at_position(i), i)
        end
      end
      alias_method :shift_out_right_with_index, :shift_out_right

      # Returns the bit at the given bit position if it exists, otherwise
      # returns an un-writable bit
      def bit_at_position(i)
        reg = regs.find { |reg| reg_contains_position?(reg, i) }
        if reg
          reg[i - bit_shift_for_reg(reg)]
        else
          dummy_bit
        end
      end

      # @api private
      def reg_contains_position?(reg, position)
        start = bit_shift_for_reg(reg)
        stop = start + reg.size - 1
        position >= start && position <= stop
      end

      # Returns the bit at the given bit position if it exists, otherwise
      # returns an un-writable bit
      def [](i)
        bit_at_position(i)
      end

      # @api private
      def dummy_bit
        @dummy_bit ||= Bit.new(self, 0, writable: false)
      end

      # Call the clear_flags on all contained registers
      def clear_flags
        @regs.each(&:clear_flags)
      end
    end
  end
end
