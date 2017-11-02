require 'json'
module Origen
  module Registers
    # The register class can be used to represent not only h/ware resgisters,
    # but really any entity which has an address and data component, such as a specific RAM location.<br>
    # Any registers instantiated through Origen::Registers#add_reg are instances of this class.
    #
    # All methods in BitCollection can also be called on a Reg object.
    class Reg
      include Origen::SubBlocks::Path
      include Origen::SubBlocks::Domains

      # These attributes can be defined on a register at definition time and will get applied
      # to all of its contained bits unless a specific bit has its own definition of the same
      # attribute
      REG_LEVEL_ATTRIBUTES = {
        feature:   {},
        reset:     { aliases: [:res] },
        memory:    {},
        path:      { aliases: [:hdl_path] },
        abs_path:  { aliases: [:absolute_path] },
        access:    {},
        bit_order: {}
      }

      # Returns the object that own the register.
      # ==== Example
      #   $soc.reg(:blah).owner   # Returns the $soc object
      attr_reader :owner
      alias_method :parent, :owner
      # The base address of the register, this will be set dynamically
      # by Origen based on the parent's base address
      attr_accessor :base_address
      attr_writer :address # :nodoc:
      # Returns an integer representing the number of bits in the register
      attr_reader :size
      # The register name
      attr_accessor :name
      # Any feature associated with the register
      attr_accessor :feature

      attr_accessor :grows_backwards # :nodoc:
      attr_accessor :lookup # :nodoc:
      # Returns a full path to the file in which the register was defined
      attr_reader :define_file
      # Returns any application-specific meta-data attatched to the given register
      attr_accessor :meta
      alias_method :meta_data, :meta
      alias_method :metadata, :meta
      # If the given register's reset data is backed by memory, the memory address can
      # be recorded in this attribute
      attr_accessor :memory

      # Normally shouldn't be called directly, instantiate through add_reg
      # Upon initialization bits are stored as follows:
      # @bits -
      # An array of bit objects in position order, @bits[5] corresponds
      # to the bit as position r
      # @lookup -
      # A Hash lookup table for quickly accessing bit objects by name
      # @lookup = { :bit_or_bus_name => {:pos => 3, :bits => 4} }
      def initialize(owner, address, size, name, options = {}) # :nodoc:
        @owner = owner
        @address = address
        @size = size
        @bits = []
        @lookup = {}
        @name = name
        @init_as_writable = options.delete(:init_as_writable)
        @define_file = options.delete(:define_file)
        REG_LEVEL_ATTRIBUTES.each do |attribute, _meta|
          instance_variable_set("@#{attribute}", options.delete(attribute))
        end
        @description_from_api = {}
        description = options.delete(:description)
        if description
          @description_from_api[:_reg] = description.split(/\r?\n/)
        end
        @meta = default_reg_metadata.merge(options.delete(:meta) || {})

        # Initialize with unwritable bits that read back as zero, can override this
        # to make all writable by default by setting the :init_writable option to true
        @size.times do |n|
          @bits << Bit.new(self, n, writable: @init_as_writable, undefined: true)
        end

        add_bits_from_options(options)
      end

      # Returns the bit order attribute of the register (either :msb0 or :lsb0). If
      # not explicitly defined on this register it will be inherited from the parent
      # and will default to :lsb0 at the top-level
      def bit_order
        @bit_order ||= parent.respond_to?(:bit_order) ? parent.bit_order : :lsb0
      end

      def freeze
        bits.each(&:freeze)
        # Call any methods which cache results to generate the instance variables
        # before they are frozen
        address
        super
      end

      def bind(bitname, live_parameter)
        unless live_parameter.respond_to?(:is_a_live_parameter?) && live_parameter.is_a_live_parameter?
          fail 'Only live updating parameters should be bound, make sure you have not missed .live in the path to the parameter!'
        end
        @parameter_bound_bits ||= {}
        @parameter_bound_bits[bitname] = live_parameter
      end

      def has_parameter_bound_bits?
        @parameter_bound_bits && !@parameter_bound_bits.empty?
      end

      def update_bound_bits
        @updating_bound_bits = true
        @parameter_bound_bits.each do |name, val|
          bits(name).write(val)
        end
        @updating_bound_bits = false
      end

      def updating_bound_bits?
        @updating_bound_bits
      end

      def inspect(options = {})
        # This fancy_output option is passed in via option hash
        #  Even better, the output could auto-detect 7-bit vs 8-bit terminal output and adjust the parameter, but that's for another day
        fancy_output = options[:fancy_output].nil? ? true : options[:fancy_output]
        if fancy_output
          horiz_double_line = '═'
          horiz_double_tee_down = '╤'
          horiz_double_tee_up = '╧'
          corner_double_up_left = '╒'
          corner_double_up_right = '╕'
          horiz_single_line = '─'
          horiz_single_tee_down = '┬'
          horiz_single_tee_up = '┴'
          horiz_single_cross = '┼'
          horiz_double_cross = '╪'
          corner_single_down_left = '└'
          corner_single_down_right = '┘'
          vert_single_line = '│'
          vert_single_tee_left = '┤'
          vert_single_tee_right = '├'
        else
          horiz_double_line = '='
          horiz_double_tee_down = '='
          horiz_double_tee_up = '='
          corner_double_up_left = '.'
          corner_double_up_right = '.'
          horiz_single_line = '-'
          horiz_single_tee_down = '-'
          horiz_single_tee_up = '-'
          horiz_single_cross = '+'
          horiz_double_cross = '='
          corner_single_down_left = '`'
          corner_single_down_right = '\''
          vert_single_line = '|'
          vert_single_tee_left = '<'
          vert_single_tee_right = '>'
        end
        bit_width = 13
        desc = ["\n0x%X - :#{name}" % address]
        r = size % 8
        if r == 0 || (size > 8 && bit_order == :msb0)
          desc << ('  ' + corner_double_up_left + ((horiz_double_line * bit_width + horiz_double_tee_down) * 8)).chop + corner_double_up_right
        else
          if bit_order == :lsb0
            desc << ('  ' + (' ' * (bit_width + 1) * (8 - r)) + corner_double_up_left + ((horiz_double_line * bit_width + horiz_double_tee_down) * r)).chop + corner_double_up_right
          else
            desc << ('  ' + corner_double_up_left + ((horiz_double_line * bit_width + horiz_double_tee_down) * r)).chop + corner_double_up_right
          end
        end

        # "<#{self.class}: #{self.name}>"
        num_bytes = (size / 8.0).ceil
        num_bytes.times do |byte_index|
          # Need to add support for little endian regs here?
          byte_number = num_bytes - byte_index
          if bit_order == :lsb0
            max_bit = (byte_number * 8) - 1
            min_bit = max_bit - 8 + 1
          else
            min_bit = (byte_index * 8)
            max_bit = min_bit + 7
          end

          # BIT INDEX ROW
          line = '  '
          line_complete = false
          8.times do |i|
            if bit_order == :lsb0
              bit_num = (byte_number * 8) - i - 1
            else
              bit_num = (byte_index * 8) + i
            end
            if bit_num > size - 1
              if bit_order == :msb0 && bit_num == size
                line += vert_single_line
                line_complete = true
              else
                line << ' ' + ''.center(bit_width) unless line_complete
              end
            else
              line << vert_single_line + "#{bit_num}".center(bit_width)
            end
          end
          line += vert_single_line unless line_complete
          desc << line

          # BIT NAME ROW
          line = '  '
          first_done = false
          line_complete = false
          named_bits include_spacers: true do |name, bit, bitcounter|
            if _bit_in_range?(bit, max_bit, min_bit)
              if bit_order == :lsb0
                if max_bit > (size - 1) && !first_done
                  (max_bit - (size - 1)).times do
                    line << ' ' * (bit_width + 1)
                  end
                end
              end

              if bit.size > 1

                if name
                  if bitcounter.nil?
                    if bit_order == :lsb0
                      bit_name = "#{name}[#{_max_bit_in_range(bit, max_bit, min_bit)}:#{_min_bit_in_range(bit, max_bit, min_bit)}]"
                    else
                      bit_name = "#{name}[#{_min_bit_in_range(bit, max_bit, min_bit)}:#{_max_bit_in_range(bit, max_bit, min_bit)}]"
                    end
                    bit_span = _num_bits_in_range(bit, max_bit, min_bit)

                  else
                    upper = _max_bit_in_range(bit, max_bit, min_bit) + bitcounter - bit.size
                    lower = _min_bit_in_range(bit, max_bit, min_bit) + bitcounter - bit.size
                    if bit_order == :lsb0
                      bit_name = "#{name}[#{upper}:#{lower}]"
                    else
                      bit_name = "#{name}[#{upper}:#{lower}]"
                    end
                    bit_span = upper - lower + 1
                  end
                  width = (bit_width * bit_span) + bit_span - 1
                  if bit_name.length > width
                    line << vert_single_line + "#{bit_name[0..width - 2]}*"
                  else
                    line << vert_single_line + bit_name.center(width)
                  end

                else
                  bit.shift_out_left do |bit|
                    if _index_in_range?(bit.position, max_bit, min_bit)
                      line << vert_single_line + ''.center(bit_width)
                    end
                  end
                end

              else
                if name
                  bit_name = "#{name}"
                  if bit_name.length > bit_width
                    txt = "#{bit_name[0..bit_width - 2]}*"
                  else
                    txt = bit_name
                  end
                else
                  txt = ''
                end
                line << vert_single_line + txt.center(bit_width)
              end
            end
            first_done = true
          end
          line += vert_single_line
          desc << line

          # BIT STATE ROW
          line = '  '
          first_done = false
          named_bits include_spacers: true do |name, bit, _bitcounter|
            if _bit_in_range?(bit, max_bit, min_bit)
              if bit_order == :lsb0
                if max_bit > (size - 1) && !first_done
                  (max_bit - (size - 1)).times do
                    line << ' ' * (bit_width + 1)
                  end
                end
              end

              if bit.size > 1
                if name
                  if bit.has_known_value?
                    value = '0x%X' % bit.val[_max_bit_in_range(bit, max_bit, min_bit).._min_bit_in_range(bit, max_bit, min_bit)]
                  else
                    if bit.reset_val == :undefined
                      value = 'X'
                    else
                      value = 'M'
                    end
                  end
                  value += _state_desc(bit)
                  bit_span = _num_bits_in_range(bit, max_bit, min_bit)
                  width = bit_width * bit_span
                  line << vert_single_line + value.center(width + bit_span - 1)
                else
                  bit.shift_out_left do |bit|
                    if _index_in_range?(bit.position, max_bit, min_bit)
                      line << vert_single_line + ''.center(bit_width)
                    end
                  end
                end
              else
                if name
                  if bit.has_known_value?
                    val = bit.val
                  else
                    if bit.reset_val == :undefined
                      val = 'X'
                    else
                      val = 'M'
                    end
                  end
                  value = "#{val}" + _state_desc(bit)
                  line << vert_single_line + value.center(bit_width)
                else
                  line << vert_single_line + ''.center(bit_width)
                end
              end
            end
            first_done = true
          end
          line += vert_single_line
          desc << line

          if size >= 8
            r = size % 8
            if byte_index == 0 && r != 0 && bit_order == :lsb0
              desc << ('  ' + corner_double_up_left + ((horiz_double_line * bit_width + horiz_double_tee_down) * (8 - r)).chop + horiz_double_cross + (horiz_single_line * (bit_width + 1) * r)).chop + vert_single_tee_left
            elsif (byte_index == num_bytes - 1) && r != 0 && bit_order == :msb0
              desc << ('  ' + corner_single_down_left + ((horiz_single_line * bit_width + horiz_single_tee_up) * r)).chop + corner_single_down_right
            elsif (byte_index == num_bytes - 2) && r != 0 && bit_order == :msb0
              desc << '  ' + vert_single_tee_right + ((horiz_single_line * bit_width + horiz_single_cross) * r) + ((horiz_single_line * bit_width + horiz_single_tee_up) * (8 - r)).chop + corner_single_down_right
            else
              if byte_index == num_bytes - 1
                desc << ('  ' + corner_single_down_left + ((horiz_single_line * bit_width + horiz_single_tee_up) * 8)).chop + corner_single_down_right
              else
                desc << ('  ' + vert_single_tee_right + ((horiz_single_line * bit_width + horiz_single_cross) * 8)).chop + vert_single_tee_left
              end
            end
          else
            if bit_order == :lsb0
              desc << ('  ' + (' ' * (bit_width + 1) * (8 - size)) + corner_single_down_left + ((horiz_single_line * bit_width + horiz_single_tee_up) * size)).chop + corner_single_down_right
            else
              desc << ('  ' + corner_single_down_left + ((horiz_single_line * bit_width + horiz_single_tee_up) * size)).chop + corner_single_down_right
            end
          end
        end
        desc.join("\n")
      end

      # Returns a hash containing all register descriptions that have been parsed so far.
      #
      # @api private
      def description_lookup
        @@description_lookup ||= {}
      end

      # Returns any application specific metadata that has been inherited by the
      # given register.
      # This does not account for any overridding that may have been applied to
      # this register specifically however, use the meta method to get that.
      def default_reg_metadata
        Origen::Registers.default_reg_metadata.merge(
          Origen::Registers.reg_metadata[owner.class] || {})
      end

      def bit_value_descriptions(bitname, options = {})
        options = {
          format: :binary
        }.merge(options)
        base = case options[:format]
               when :bin, :binary
                 2
               when :hex, :hexadecimal
                 16
               when :dec, :decimal
                 10
               else
                 fail "Unknown integer format: #{options[:format]}"
               end
        desc = {}
        description(bitname).each do |line|
          if line =~ /^\s*(\d+)\s+\|\s+(.+)/
            desc[Regexp.last_match[1].to_i(base)] = Regexp.last_match[2]
          end
        end
        desc
      end

      # Returns the full name of the register when this has been specified in the register
      # description like this:
      #
      #   # ** This is the Register Full Name **
      #   # This register blah blah
      #
      # This method will also be called by bit collections to look up the name when
      # defined in a similar manner in the bit description.
      #
      # If no name has been specified this will return nil.
      def full_name(bitname = :_reg, _options = {})
        bitname, options = :_reg, bitname if bitname.is_a?(Hash)
        desc = description(bitname).first
        # Capture something like this:
        # ** This is the full name ** - This bit blah blah
        if desc && desc =~ /\s*\*\*\s*([^\*.]*)\s*\*\*/
          Regexp.last_match[1].strip
        end
      end

      # Escapes brackets and parenthesis. Helper for description method.
      def escape_special_char(str)
        str.gsub('[', '\[').gsub(']', '\]').gsub('(', '\(').gsub(')', '\)') if str
      end

      # Returns the description of this register if any, if none then an empty array
      # will be returned
      #
      # **Note** Adding a description field will override any comment-driven documentation
      # of a register (ie markdown style comments)
      def description(bitname = :_reg, options = {})
        bitname, options = :_reg, bitname if bitname.is_a?(Hash)
        options = {
          include_name:       true,
          include_bit_values: true
        }.merge(options)
        if @description_from_api[bitname]
          desc = @description_from_api[bitname]
        else
          parse_descriptions unless description_lookup[define_file]
          begin
            desc = description_lookup[define_file][name][bitname] || []
          rescue
            desc = []
          end
        end
        desc = desc.reject do |line|
          if bitname != :_reg
            unless options[:include_bit_values]
              !!(line =~ /^\s*(\d+)\s+\|\s+(.+)/)
            end
          else
            false
          end
        end
        if desc.first
          unless options[:include_name]
            desc[0] = desc.first.sub(/\s*\*\*\s*#{escape_special_char(full_name(bitname))}\s*\*\*\s*-?\s*/, '')
          end
        end
        desc.shift while desc.first && desc.first.strip.empty?
        desc.pop while desc.last && desc.last.strip.empty?
        desc
      end
      alias_method :descriptions, :description

      # @api private
      def parse_descriptions
        desc = []
        File.readlines(define_file).each do |line|
          if line =~ /^\s*#(.*)/
            desc << Regexp.last_match[1].strip
          #              http://rubular.com/r/D8lg2P5kK1                     http://rubular.com/r/XP4ydPV8Fd
          elsif line =~ /^\s*reg\(?\s*[:"'](\w+)["']?\s*,.*\sdo/ || line =~ /^\s*.*add_reg\(?\s*[:"'](\w+)["']?\s*,.*/
            @current_reg_name = Regexp.last_match[1].to_sym
            description_lookup[define_file] ||= {}
            description_lookup[define_file][@current_reg_name] ||= {}
            description_lookup[define_file][@current_reg_name][:_reg] = desc.dup
            desc = []
          # http://www.rubular.com/r/7FidbC1JRA
          elsif @current_reg_name && line =~ /^\s*(add_bit|bit|reg\.bit)s?\(?\s*\d+\.?\.?\d*\s*,\s*:(\w+)/
            description_lookup[define_file][@current_reg_name][Regexp.last_match[2].to_sym] = desc.dup
            desc = []
          else
            desc = []
          end
        end
      end

      def contains_bits?
        true
      end

      # @api private
      def add_bits_from_options(options = {}) # :nodoc:
        # options is now an array for split bit groups or a hash if single bit/range bits
        # Now add the requested bits to the register, removing the unwritable bits as required
        options.each do |bit_id, bit_params|
          if bit_params.is_a? Hash
            description = bit_params.delete(:description)
            if description
              @description_from_api[bit_id] = description.split(/\r?\n/)
            end
            bind(bit_id, bit_params.delete(:bind)) if bit_params[:bind]
            position = bit_params[:pos] || 0
            num_bits = bit_params[:bits] || 1
            if @reset
              if @reset.is_a?(Symbol)
                bit_params[:res] = @reset
              else
                bit_params[:res] = @reset[(num_bits + position - 1), position]
              end
            end
            bit_params[:access] = @access if bit_params[:access].nil?
            bit_params[:res] = bit_params[:data] if bit_params[:data]
            bit_params[:res] = bit_params[:reset] if bit_params[:reset]
            if num_bits == 1
              add_bit(bit_id, position, bit_params)   # and add the new one
            else
              add_bus(bit_id, position, num_bits, bit_params)
            end
          elsif bit_params.is_a? Array

            description = bit_params.map { |h| h.delete(:description) }.compact.join("\n")
            unless description.empty?
              @description_from_api[bit_id] = description.split(/\r?\n/)
            end
            add_bus_scramble(bit_id, bit_params)
          end
        end
        self
      end

      # This method is called whenever reg.clone is called to make a copy of a given register.
      # Ruby will correctly copy all instance variables but it will not drill down to copy nested
      # attributes, like the bits contained in @bits.
      # This function will therefore correctly clone all bits contained in the register also.
      def initialize_copy(orig) # :nodoc:
        @bits = []
        orig.bits.each do |bit|
          @bits << bit.clone
        end
        @lookup = orig.lookup.clone
        self
      end

      # Returns a dummy register object that can be used on the fly, this can sometimes
      # be useful to configure an intricate read operation.
      # ==== Example
      #   # Read bit 5 of RAM address 0xFFFF1280
      #   dummy = Reg.dummy           # Create a dummy reg to configure the read operation
      #   dummy.address = 0xFFFF1280  # Set the address
      #   dummy.bit(5).read!(1)       # Read bit 5 expecting a 1
      def self.dummy(size = 16)
        Reg.new(self, 0, size, :dummy, init_as_writable: true)
      end

      # Returns each named bit collection contained in the register,
      def named_bits(options = {})
        options = {
          include_spacers: false
        }.merge(options)
        result = []

        # test if @lookup has any values stored as an array
        # if so it means there is a split group of bits
        # process that differently to a single bit or continuous range of bits
        # which are typically stored in a hash

        split_bits = false
        @lookup.each { |_k, v| split_bits = true if v.is_a? Array }

        if split_bits == false
          if bit_order == :lsb0
            current_pos = size
          else
            current_pos = 0
          end
          # Sort by position
          @lookup.sort_by { |_name, details| bit_order == :lsb0 ? -details[:pos] : details[:pos] }.each do |name, details|
            if bit_order == :lsb0
              pos = details[:bits] + details[:pos]
            else
              pos = details[:pos]
            end
            if options[:include_spacers] && (pos != current_pos)
              if bit_order == :lsb0
                collection = BitCollection.dummy(self, nil, size: current_pos - pos, pos: pos)
              else
                collection = BitCollection.dummy(self, nil, size: pos - current_pos, pos: current_pos)
              end
              unless collection.size == 0
                if block_given?
                  yield nil, collection
                else
                  result << [nil, collection]
                end
              end
            end
            collection = BitCollection.new(self, name)
            details[:bits].times do |i|
              collection << @bits[details[:pos] + i]
            end
            unless collection.size == 0
              if block_given?
                yield name, collection
              else
                result << [name, collection]
              end
            end
            if bit_order == :lsb0
              current_pos = details[:pos]
            else
              current_pos = details[:bits] + details[:pos]
            end
          end
          if options[:include_spacers] && ((bit_order == :lsb0 && current_pos != 0) ||
                                            bit_order == :msb0 && current_pos != size)
            if bit_order == :lsb0
              collection = BitCollection.dummy(self, nil, size: current_pos, pos: 0)
            else
              collection = BitCollection.dummy(self, nil, size: size - current_pos, pos: current_pos)
            end
            unless collection.size == 0
              if block_given?
                yield nil, collection
              else
                result << [nil, collection]
              end
            end
          end
        elsif split_bits == true # if there are split bits, need to convert all register bit values to array elements to allow sorting

          # if the register has bits split up across it, then store the bits in order of decreasing reg position
          # but first, stuff all the bits in a simple array, as single bits, or ranges of bits

          @lookup_splits = []
          @lookup.each do |k, v|
            tempbit = {}
            bitcounter = {}
            if v.is_a? Hash
              # then this is already a single bit or a continuous range so just stuff it into the array
              tempbit[k] = v
              @lookup_splits << tempbit.clone
            elsif v.is_a? Array
              # if the bitgroup is split, then decompose into single bits and continuous ranges
              v.each_with_index do |bitdetail, _i|
                if bitcounter.key?(k)
                  bitcounter[k] = bitcounter[k] + bitdetail[:bits]
                else
                  bitcounter[k] = bitdetail[:bits]
                end
                tempbit[k] = bitdetail
                @lookup_splits << tempbit.clone
              end
            end
            if v.is_a? Array
              @lookup_splits.each_with_index do |_e, q|
                groupname = @lookup_splits[q].to_a[0][0]
                if groupname == k
                  @lookup_splits[q][groupname][:bitgrouppos] = bitcounter[groupname] if groupname == k
                  bitcounter[groupname] = bitcounter[groupname] - @lookup_splits[q][groupname][:bits]
                end
              end
            end
          end
          # Now sort the array in descending order
          # Does adding the bitgrouppos need to happen after the sort ?
          @lookup_splits = @lookup_splits.sort do |a, b|
            b.to_a[0][1][:pos] <=> a.to_a[0][1][:pos]
          end

          current_pos = size
          countbits = {} # if countbits.method == nil

          @master = {}
          bitgroup = {}
          bitinfo = {}
          info = {}

          @lookup_splits.each_with_index do |hash, _i|
            name = hash.to_a[0][0]
            details = hash.to_a[0][1]
            bitcounter = hash.to_a[0][1][:bitgrouppos]
            pos = details[:bits] + details[:pos]
            if options[:include_spacers] && (pos != current_pos)
              collection = BitCollection.dummy(self, nil, size: current_pos - pos, pos: pos)
              unless collection.size == 0
                if block_given?
                  yield nil, collection, bitcounter
                else
                  result << [nil, collection, bitcounter]
                end
              end
            end
            collection = BitCollection.new(self, name)
            details[:bits].times do |i|
              collection << @bits[details[:pos] + i]
            end
            unless collection.size == 0
              if block_given?
                yield name, collection, bitcounter
              else
                result << [name, collection, bitcounter]
              end
            end
            current_pos = details[:pos]
          end
          if options[:include_spacers] && current_pos != 0
            collection = BitCollection.dummy(self, nil, size: current_pos, pos: 0)
            unless collection.size == 0
              if block_given?
                yield nil, collection, bitcounter
              else
                result << [nil, collection, bitcounter]
              end
            end
          end
        end
        unless block_given?
          result
        end
      end

      # Returns each named bit collection contained in self
      def reverse_named_bits(_options = {})
        bits = []
        named_bits { |name, bit| bits << [name, bit] }
        bits.each do |bit|
          yield bit[0], bit[1]
        end
      end

      # Returns an array of occupied bit positions
      # ==== Example
      #   reg :fstat, @base + 0x0000, :size => 8 do
      #     bit 7,  :ccif
      #     bit 6,  :rdcolerr
      #     bit 5,  :accerr
      #     bit 4,  :pviol
      #     bit 0,  :mgstat0
      #   end
      #   regs(:fstat).used_bits
      #   => [0, 4, 5, 6, 7]
      #
      # ==== Example
      #   reg :aguahb2, @base + 0x2A, :size => 8 do
      #     bit 5..2, :m0b_hbstrb, :reset => 0x0
      #     bit 1..0, :m0b_htrans, :reset => 0x2
      #   end
      #   regs(:aguahb2).used_bits
      #   => [0, 1, 2, 3, 4, 5]
      def used_bits(_options = {})
        used_bits = []
        named_bits do |_name, bit|
          used_bits << bit.position if bit.size == 1
          if bit.size > 1
            used_bits << ((bit.position)..(bit.position + bit.size - 1)).to_a
          end
        end
        used_bits.flatten!
        used_bits.sort!
        used_bits
      end

      # Returns true if any named_bits exist, false if used_bits is an empty array
      def used_bits?(_options = {})
        used_bits.size > 0
      end

      # Returns an array of unoccupied bit positions
      # ==== Example
      #   reg :fstat, @base + 0x0000, :size => 8 do
      #     bit 7,  :ccif
      #     bit 6,  :rdcolerr
      #     bit 5,  :accerr
      #     bit 4,  :pviol
      #     bit 0,  :mgstat0
      #   end
      #   regs(:fstat).empty_bits
      #   => [1, 2, 3]
      #
      # ==== Example
      #   reg :aguahb2, @base + 0x2A, :size => 8 do
      #     bit 5..2, :m0b_hbstrb, :reset => 0x0
      #     bit 1..0, :m0b_htrans, :reset => 0x2
      #   end
      #   regs(:aguahb2).empty_bits
      #   => [6, 7]
      def empty_bits(_options = {})
        array_span = (0..(size - 1)).to_a
        empty_bits = array_span - used_bits
        empty_bits
      end

      # Returns true if any named_bits exist, false if used_bits is an empty array
      def empty_bits?(_options = {})
        empty_bits.size > 0
      end

      # Proxies requests from bit collections to the register owner
      def request(operation, options = {}) # :nodoc:
        if operation == :read_register
          object = reader
          (Origen.top_level || owner).read_register_missing!(self) unless object
        else
          object = writer
          (Origen.top_level || owner).write_register_missing!(self) unless object
        end
        object.send(operation, self, options)
        self
      end

      # Returns the object that will be responsible for writing the given register
      def writer
        @writer ||= lookup_operation_handler(:write_register)
      end

      # Returns the object that will be responsible for reading the given register
      def reader
        @reader ||= lookup_operation_handler(:read_register)
      end

      # @api private
      def lookup_operation_handler(operation)
        # Could have made the controller be the owner when assigned above, but may have run
        # into problems with the reg meta data stuff
        reg_owner = owner.respond_to?(:controller) && owner.controller ? owner.controller : owner
        if reg_owner.respond_to?(operation)
          reg_owner
        elsif reg_owner.respond_to?(:owner) && reg_owner.owner.respond_to?(operation)
          reg_owner.owner
        elsif Origen.top_level && Origen.top_level.respond_to?(operation)
          Origen.top_level
        end
      end

      # Returns the relative address of the given register, equivalent to calling
      # reg.address(:relative => true)
      def offset
        address(relative: true)
      end

      # Returns the register address added to its current base_address value (if any).
      #
      # @param [Hash] options
      # @option options [Boolean] :relative (false) Return the address without adding the base address (if present)
      def address(options = {})
        options = {
          relative: false
        }.merge(options)
        address = @address
        domain_option = options[:domains] || options[:domain]
        @domain_option ||= domain_option unless frozen?
        # Blow the cache when the domain option changes
        @base_address_applied = nil unless @domain_option == domain_option
        unless @base_address_applied
          # Give highest priority to the original API which allowed the object
          # doing register read/write to define a base_address method
          if (writer && writer.methods.include?(:base_address) && writer.method(:base_address).arity != 0) ||
             (reader && reader.methods.include?(:base_address) && reader.method(:base_address).arity != 0)
            # This currently assumes that the base address is always the same
            # for reading and writing
            if writer && writer.respond_to?(:base_address) && writer.method(:base_address).arity != 0
              self.base_address = writer.base_address(self)
            elsif reader && reader.respond_to?(:base_address) && reader.method(:base_address).arity != 0
              self.base_address = reader.base_address(self)
            end
          else
            o = owner.is_a?(Container) ? owner.owner : owner
            d = domain_option || domains
            if o && o.reg_base_address(domain: d)
              self.base_address = o.reg_base_address(domain: d)
            end
          end
          @base_address_applied = true
        end
        unless options[:relative]
          address += base_address if base_address
        end
        if options[:address_type]
          Origen.deprecate 'Specifying the address_type of a register address will be removed from Origen 3'
          case options[:address_type]
            when :byte
              address = address * 2
            when :word
              address = address
            when :longword
              address = address / 2
            else
              fail 'Unknown address type requested!'
          end
        end
        address
      end
      alias_method :addr, :address

      # Returns true if the register owner matches the given name. A match will be detected
      # if the class names of the register's owner contains the given name.
      #
      # Alternatively if the register owner implements a method called reg_owner_alias
      # then the value that this returns instead will also be considered when checking if the given
      # name matches. This method can return an array of names if multiple aliases are required.
      #
      # Aliases can be useful for de-coupling the commonly used name, e.g. "NVM" from the actual
      # class name.
      #
      # @example
      #   class C90NVM
      #     include Origen::Registers
      #
      #     def initialize
      #       add_reg :clkdiv, 0x3, 16, :div => {:bits => 8}
      #     end
      #
      #   end
      #
      #   reg = C90NVM.new.reg(:clkdiv)
      #   reg.owned_by?(:ram)      # => false
      #   reg.owned_by?(:nvm)      # => true
      #   reg.owned_by?(:c90nvm)   # => true
      #   reg.owned_by?(:c40nvm)   # => false
      #   reg.owned_by?(:flash)    # => false
      #
      # @example Using an alias
      #   class C90NVM
      #     include Origen::Registers
      #
      #     def initialize
      #       add_reg :clkdiv, 0x3, 16, :div => {:bits => 8}
      #     end
      #
      #     def reg_owner_alias
      #       "flash"
      #     end
      #
      #   end
      #
      #   reg = C90NVM.new.reg(:clkdiv)
      #   reg.owned_by?(:ram)      # => false
      #   reg.owned_by?(:nvm)      # => true
      #   reg.owned_by?(:c90nvm)   # => true
      #   reg.owned_by?(:c40nvm)   # => false
      #   reg.owned_by?(:flash)    # => true
      def owned_by?(name)
        !!(owner.class.to_s =~ /#{name}/i) || begin
          if owner.respond_to?(:reg_owner_alias)
            [owner.reg_owner_alias].flatten.any? do |al|
              al.to_s =~ /#{name}/i
            end
          else
            false
          end
        end
      end

      # Returns true if the register contains a bit(s) matching the given name
      # ==== Example
      #   add_reg :control, 0x55, :status => {:pos => 1}
      #
      #   reg(:control).has_bit?(:result)     # => false
      #   reg(:control).has_bit?(:status)     # => true
      def has_bit?(name)
        @lookup.include?(name)
      end
      alias_method :has_bits?, :has_bit?
      alias_method :has_bit, :has_bit?
      alias_method :has_bits, :has_bit?

      # Add a bit to the register, should only be called internally
      def add_bit(id, position, options = {}) # :nodoc:
        options = { data: @bits[position].data,  # If undefined preserve any data/reset value that has
                    res:  @bits[position].data,   # already been applied at reg level
                  }.merge(options)

        @lookup[id] = { pos: position, bits: 1, feature: options[:feature] }
        @bits.delete_at(position)    # Remove the initial bit from this position

        @bits.insert(position, Bit.new(self, position, options))
        self
      end

      # Add a bus to the register, should only be called internally
      def add_bus(id, position, size, options = {}) # :nodoc:
        default_data = 0
        size.times do |n|
          default_data |= @bits[position + n].data << n
        end
        options = { data: default_data,  # If undefined preserve any data/reset value that has
                    res:  default_data,   # already been applied at reg level
                  }.merge(options)

        @lookup[id] = { pos: position, bits: size }
        size.times do |n|
          bit_options = options.dup
          bit_options[:data] = options[:data][n]
          if options[:res].is_a?(Symbol)
            bit_options[:res]  = options[:res]
          else
            bit_options[:res]  = options[:res][n]
          end
          @bits.delete_at(position + n)
          @bits.insert(position + n, Bit.new(self, position + n, bit_options))
        end
        self
      end

      def add_bus_scramble(id, array_of_hashes = [])
        array_of_hashes.each do |options|
          bind(id, options.delete(:bind)) if options[:bind]
          position = options[:pos] || 0
          num_bits = options[:bits] || 1
          size = options[:bits]
          options[:data] = options[:data] if options[:data]
          options[:res] = options[:reset] if options[:reset]
          default_data = 0
          size.times do |n|
            default_data |= @bits[position + n].data << n
          end
          options = { data: default_data,  # If undefined preserve any data/reset value that has
                      res:  default_data,   # already been applied at reg level
                    }.merge(options)

          @lookup[id] = [] if @lookup[id].nil?
          @lookup[id] = @lookup[id].push(pos: position, bits: size)
          size.times do |n|
            bit_options = options.dup
            bit_options[:data] = options[:data][n]
            bit_options[:res]  = options[:res][n]
            @bits.delete_at(position + n)
            @bits.insert(position + n, Bit.new(self, position + n, bit_options))
          end
          self
        end
      end

      # Delete the bits in the collection from the register
      def delete_bit(collection)
        [collection.name].flatten.each do |name|
          @lookup.delete(name)
        end
        collection.each do |bit|
          @bits.delete_at(bit.position)    # Remove the bit
          @bits.insert(bit.position, Bit.new(self, bit.position, writable: @init_as_writable))
        end
        self
      end
      alias_method :delete_bits, :delete_bit

      # @api private
      def expand_range(range)
        if range.first > range.last
          range = Range.new(range.last, range.first)
        end
        range.each do |i|
          yield i
        end
      end

      # Returns the bit object(s) responding to the given name, wrapped in a BitCollection.
      # This method also accepts multiple name possibilities, if neither bit exists in
      # the register it will raise an error, otherwise it will return the first match.
      # If no args passed in, it will return a BitCollection containing all bits.
      # If a number is passed in then the bits from those positions are returned.
      # ==== Example
      #   add_reg :control, 0x55, :status => {:pos => 1, :bits => 2},
      #                           :fail   => {:pos => 0}
      #
      #   reg(:control).bit(:fail)              # => Returns a BitCollection containing the fail bit
      #   reg(:control).bits(:status)           # => Returns a BifCollection containing the status bits
      #   reg(:control).bit(:bist_fail, :fail)  # => Returns a BitCollection containing the fail bit
      #   reg(:control).bit(0)                  # => Returns a BitCollection containing the fail bit
      #   reg(:control).bit(1)                  # => Returns a BitCollection containing status bit
      #   reg(:control).bit(1,2)                # => Returns a BitCollection containing both status bits
      def bit(*args)
        multi_bit_names = false
        # return get_bits_with_constraint(nil,:default) if args.size == 0
        constraint = extract_feature_params(args)
        if constraint.nil?
          constraint = :default
        end
        collection = BitCollection.new(self, :unknown)
        if args.size == 0
          collection.add_name(name)
          @bits.each do |bit|
            collection << get_bits_with_constraint(bit.position, constraint)
          end
        else
          args.flatten!
          args.sort!
          args.each do |arg_item|
            if arg_item.is_a?(Fixnum)
              b = get_bits_with_constraint(arg_item, constraint)
              collection << b if b
            elsif arg_item.is_a?(Range)
              expand_range(arg_item) do |bit_number|
                collection << get_bits_with_constraint(bit_number, constraint)
              end
            else
              multi_bit_names = args.size > 1
              # Reaches here if bit name is specified
              if @lookup.include?(arg_item)
                split_bits = false
                @lookup.each { |_k, v| split_bits = true if v.is_a? Array }
                coll = get_lookup_feature_bits(arg_item, constraint, split_bits)
                if coll
                  coll.each do |b|
                    collection.add_name(arg_item)
                    collection << b
                  end
                end
              end
            end
          end
        end
        if collection.size == 0
          # Originally Origen returned nil when asking for a bit via an index which does not
          # exist, e.g. reg[1000] => nil
          # The args numeric clause here is to maintain that behavior
          if Origen.config.strict_errors && !args.all? { |arg| arg.is_a?(Numeric) }
            puts "Register #{@name} does not have a bits(s) named :#{args.join(', :')} or it might not be enabled."
            puts 'This could also be a typo, these are the valid bit names:'
            puts @lookup.keys
            fail 'Missing bits error!'
          end
          nil
        else
          if multi_bit_names
            collection.sort_by!(&:position)
          end
          collection
        end
      end
      alias_method :bits, :bit
      alias_method :[], :bit

      def get_bits_with_constraint(number, params)
        return nil unless @bits[number]
        if (params == :default || !params) && @bits[number].enabled?
          @bits[number]
        elsif params == :none && !@bits[number].has_feature_constraint?
          @bits[number]
        elsif params == :all
          @bits[number]
        elsif params.class == Array
          params.each do |param|
            unless @bits[number].enabled_by_feature?(param)
              return nil
            end
            @bits[number]
          end
        elsif @bits[number].enabled_by_feature?(params)
          @bits[number]
        else
          return Bit.new(self, number, writable: false)
        end
      end

      def get_lookup_feature_bits(bit_name, params, split_group_reg)
        ##
        if split_group_reg == false # if this register has single bits and continuous ranges

          if @lookup.include?(bit_name)
            collection = BitCollection.new(self, bit_name)
            (@lookup[bit_name][:bits]).times do |i|
              collection << @bits[@lookup[bit_name][:pos] + i]
            end
            if !params || params == :default
              if collection.enabled?
                return collection
              end
            elsif params == :none
              unless collection.has_feature_constraint?
                return collection
              end
            elsif params == :all
              return collection
            elsif params.class == Array
              if params.all? { |param| collection.enabled_by_feature?(param) }
                return collection
              end
            else
              if collection.enabled_by_feature?(params)
                return collection
              end
            end
            return BitCollection.dummy(self, bit_name, size: collection.size, pos: @lookup[bit_name][:pos])
          else
            return []
          end

        elsif split_group_reg == true # if this registers has split bits in its range
          if @lookup.is_a?(Hash) # && @lookup.include?(bit_name)
            collection = false
            @lookup.each do |k, v|  # k is the bitname, v is the hash of bit data
              if k == bit_name
                collection ||= BitCollection.new(self, k)
                if v.is_a?(Array)
                  v.reverse_each do |pb|  # loop each piece of bit group data
                    (pb[:bits]).times do |i|
                      collection << @bits[pb[:pos] + i]
                    end
                  end
                else
                  (v[:bits]).times do |i|
                    collection << @bits[v[:pos] + i]
                  end
                end
              end
            end
            if !params || params == :default
              if collection.enabled?
                return collection
              end
            elsif params == :none
              unless collection.has_feature_constraint?
                return collection
              end
            elsif params == :all
              return collection
            elsif params.class == Array
              if params.all? { |param| collection.enabled_by_feature?(param) }
                return collection
              end
            else
              if collection.enabled_by_feature?(params)
                return collection
              end
            end
            if @lookup.is_a?(Hash) && @lookup[bit_name].is_a?(Array)
              return BitCollection.dummy(self, bit_name, size: collection.size, pos: @lookup[bit_name][0][:pos])
            else
              return BitCollection.dummy(self, bit_name, size: collection.size, pos: @lookup[bit_name[:pos]])
            end
          else
            return []
          end
        end
      end

      def extract_feature_params(args)
        index = args.find_index { |arg| arg.class == Hash }
        if index
          params = args.delete_at(index)
        else
          params = nil
        end

        if params
          return params[:enabled_features] || params[:enabled_feature]
        else
          return nil
        end
      end

      # All other Reg methods are delegated to BitCollection
      def method_missing(method, *args, &block) # :nodoc:
        if method.to_sym == :to_ary || method.to_sym == :to_hash
          nil
        elsif meta_data_method?(method)
          extract_meta_data(method, *args)
        else
          if BitCollection.instance_methods.include?(method)
            to_bit_collection.send(method, *args, &block)
          elsif has_bits?(method)
            bits(method)
          else
            super
          end
        end
      end

      def to_bit_collection
        BitCollection.new(self, name, @bits)
      end

      # Recognize that Reg responds to all BitCollection methods methods based on
      # application-specific meta data properties
      def respond_to?(*args) # :nodoc:
        sym = args.first.to_sym
        meta_data_method?(sym) || has_bits?(sym) || super(sym) || BitCollection.instance_methods.include?(sym)
      end

      # Copy overlays from one reg object to another
      # ==== Example
      #   reg(:data_copy).has_overlay?        # => false
      #   reg(:data).overlay("data_val")
      #   reg(:data_copy).copy_overlays_from(reg(:data))
      #   reg(:data_copy).has_overlay?        # => true
      def copy_overlays_from(reg, options = {})
        size.times do |i|
          source_bit = reg.bit[i]
          if source_bit.has_overlay?
            ov = source_bit.overlay_str
            # If an id has been supplied make sure any trailing ID in the source is
            # changed to supplied identifier
            ov.gsub!(/_\d$/, "_#{options[:update_id]}") if options[:update_id]
            @bits[i].overlay(ov)
          end
        end
        self
      end

      # Copies data from one reg object to another
      # ==== Example
      #   reg(:data_copy).data                # => 0
      #   reg(:data).write(0x1234)
      #   reg(:data_copy).copy_data_from(reg(:data))
      #   reg(:data_copy).data                # => 0x1234
      def copy_data_from(reg)
        size.times do |i|
          @bits[i].write(reg.bit[i].data)
        end
        self
      end

      # Copies data and overlays from one reg object to another, it does not copy
      # read or store flags
      def copy(reg)
        size.times do |i|
          source_bit = reg.bit[i]
          @bits[i].overlay(source_bit.overlay_str) if source_bit.has_overlay?
          @bits[i].write(source_bit.data)
        end
        self
      end

      # Returns the BITWISE AND of reg with another reg or a number, the state of
      # both registers remains unchanged
      # ==== Example
      #   reg(:data).write(0x5555)
      #   reg(:data2).write(0xFFFF)
      #   reg(:data) & 0xFF00         # => 0x5500
      #   reg(:data) & reg(:data2)    # => 0x5555
      def &(val)
        data & Reg.clean_value(val)
      end

      # Returns the BITWISE OR of reg with another reg or a number, the state of
      # both registers remains unchanged
      def |(val)
        data | Reg.clean_value(val)
      end

      # Returns the SUM of reg with another reg or a number, the state of
      # both registers remains unchanged
      def +(val)
        data + Reg.clean_value(val)
      end

      # Returns the SUBTRACTION of reg with another reg or a number, the state of
      # both registers remains unchanged
      def -(val)
        data - Reg.clean_value(val)
      end

      # Returns the DIVISION of reg with another reg or a number, the state of
      # both registers remains unchanged
      def /(val)
        data / Reg.clean_value(val)
      end

      # Returns the PRODUCT of reg with another reg or a number, the state of
      # both registers remains unchanged
      def *(val)
        data * Reg.clean_value(val)
      end

      # Cleans an input value, in some cases it could be a register object, or an explicit value.
      # This will return an explicit value in either case.
      def self.clean_value(value) # :nodoc:
        value = value.val if value.respond_to?('val')  # Pull out the data value if a reg object has been passed in
        value
      end

      # @api private
      def meta_data_method?(method)
        attr_name = method.to_s.gsub(/\??=?/, '').to_sym
        if default_reg_metadata.key?(attr_name)
          if method.to_s =~ /\?/
            [true, false].include?(default_reg_metadata[attr_name])
          else
            true
          end
        else
          false
        end
      end

      def extract_meta_data(method, *args)
        method = method.to_s.sub('?', '')
        if method =~ /=/
          instance_variable_set("@#{method.sub('=', '')}", args.first)
        else
          instance_variable_get("@#{method}") || meta[method.to_sym]
        end
      end

      # Returns true if the register is constrained by the given/any feature
      def enabled_by_feature?(name = nil)
        if !name
          !!feature
        else
          if feature.class == Array
            feature.each do |f|
              if f == name
                return true
              end
            end
            return false
          else
            return feature == name
          end
        end
      end
      alias_method :has_feature_constraint?, :enabled_by_feature?

      # Query the owner heirarchy to see if this register is enabled
      def enabled?
        if feature
          value = false
          current_owner = self
          if feature.class == Array
            feature.each do |f|
              current_owner = self
              loop do
                if current_owner.respond_to?(:owner)
                  current_owner = current_owner.owner
                  if current_owner.respond_to?(:has_feature?)
                    if current_owner.has_feature?(f)
                      value = true
                      break
                    end
                  end
                else # if current owner does not have a owner
                  value = false
                  break
                end
              end # loop end
              unless value
                if Origen.top_level && \
                   Origen.top_level.respond_to?(:has_feature?) && \
                   Origen.top_level.has_feature?(f)
                  value = true
                  unless value
                    break
                  end
                end
              end
              unless value
                break # break if feature not found and return false
              end
            end # iterated through all features in array
            return value
          else # if feature.class != Array
            loop do
              if current_owner.respond_to?(:owner)
                current_owner = current_owner.owner
                if current_owner.respond_to?(:has_feature?)
                  if current_owner.has_feature?(feature)
                    value = true
                    break
                  end
                end
              else # if current owner does not have a owner
                value = false
                break
              end
            end # loop end
            unless value
              if Origen.top_level && \
                 Origen.top_level.respond_to?(:has_feature?) && \
                 Origen.top_level.has_feature?(feature)
                value = true
              end
            end
            return value
          end
        else
          return true
        end
      end

      # Returns true if any of the bits within this register has feature
      # associated with it.
      def has_bits_enabled_by_feature?(name = nil)
        if !name
          bits.any?(&:has_feature_constraint?)
        else
          bits.any? { |bit| bit.enabled_by_feature?(name) }
        end
      end

      def to_json(*args)
        JSON.pretty_generate({
                               name:        name,
                               full_name:   full_name,
                               address:     address,
                               offset:      offset,
                               size:        size,
                               path:        path,
                               reset_value: reset_value,
                               description: description(include_name: false, include_bit_values: false),
                               bits:        named_bits.map do |name, bit|
                                 {
                                   name:        name,
                                   full_name:   bit.full_name,
                                   position:    bit.position,
                                   size:        bit.size,
                                   reset_value: bit.reset_value,
                                   access:      bit.access,
                                   description: bit.description(include_name: false, include_bit_values: false),
                                   bit_values:  bit.bit_value_descriptions.map do |val, desc|
                                     {
                                       value:       val,
                                       description: desc
                                     }
                                   end
                                 }
                               end
                             }, *args)
      end

      private

      def _state_desc(bits)
        state = []
        unless bits.readable? && bits.writable?
          if bits.readable?
            state << 'RO'
          else
            state << 'WO'
          end
        end
        state << 'Rd' if bits.is_to_be_read?
        state << 'Str' if bits.is_to_be_stored?
        state << 'Ov' if bits.has_overlay?
        if state.empty?
          ''
        else
          "(#{state.join('|')})"
        end
      end

      def _max_bit_in_range(bits, max, _min)
        upper = bits.position + bits.size - 1
        [upper, max].min - bits.position
      end

      def _min_bit_in_range(bits, _max, min)
        lower = bits.position
        [lower, min].max - bits.position
      end

      # Returns true if some portion of the given bits falls
      # within the given range
      def _bit_in_range?(bits, max, min)
        upper = bits.position + bits.size - 1
        lower = bits.position
        !((lower > max) || (upper < min))
      end

      # Returns the number of bits from the given bits that
      # fall within the given range
      def _num_bits_in_range(bits, max, min)
        upper = bits.position + bits.size - 1
        lower = bits.position
        [upper, max].min - [lower, min].max + 1
      end

      # Returns true if the given number is is the
      # given range
      def _index_in_range?(i, max, min)
        !((i > max) || (i < min))
      end

      def _bit_rw(bits)
        if bits.readable? && bits.writable?
          'RW'
        elsif bits.readable?
          'RO'
        elsif bits.writable?
          'WO'
        else
          'X'
        end
      end
    end
  end
end
