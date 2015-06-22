module Origen
  module Registers
    # Models bits within Reg objects
    class Bit
      # The :access property of registers or bits can be set to any of the following
      # key values. Implemented refers to whether the behaviour is accurately modelled
      # by the Origen register model or not.
      ACCESS_CODES = {
        ro:    { implemented: false, description: 'Read-Only' },
        rw:    { implemented: true,  description: 'Read-Write' },
        rc:    { implemented: false, description: 'Read-only, Clear-on-read' },
        rs:    { implemented: false, description: "Set-on-read (all bits become '1' on read)" },
        wrc:   { implemented: false, description: 'Writable, clear-on-read' },
        wrs:   { implemented: false, description: 'Writable, Sets-on-read' },
        wc:    { implemented: false, description: 'Clear-on-write' },
        ws:    { implemented: false, description: 'Set-on-write' },
        wsrc:  { implemented: false, description: 'Set-on-write, clear-on-read' },
        wcrs:  { implemented: false, description: 'Clear-on-write, set-on-read' },
        w1c:   { implemented: false, description: "Write '1' to clear bits" },
        w1s:   { implemented: false, description: "Write '1' to set bits" },
        w1t:   { implemented: false, description: "Write '1' to toggle bits" },
        w0c:   { implemented: false, description: "Write '0' to clear bits" },
        w0s:   { implemented: false, description: "Write '0' to set bits" },
        w0t:   { implemented: false, description: "Write '0' to toggle bits" },
        w1src: { implemented: false, description: "Write '1' to set and clear-on-read" },
        w1crs: { implemented: false, description: "Write '1' to clear and set-on-read" },
        w0src: { implemented: false, description: "Write '0' to set and clear-on-read" },
        w0crs: { implemented: false, description: "Write '0' to clear and set-on-read" },
        wo:    { implemented: false, description: 'Write-only' },
        woc:   { implemented: false, description: "When written sets the field to '0'. Read undeterministic" },
        worz:  { implemented: false, description: 'Write-only, Reads zero' },
        wos:   { implemented: false, description: "When written sets all bits to '1'. Read undeterministic" },
        w1:    { implemented: false, description: 'Write-once. Next time onwards, write is ignored. Read returns the value' },
        wo1:   { implemented: false, description: 'Write-once. Next time onwards, write is ignored. Read is undeterministic' },
        dc:    { implemented: false, description: 'RW but no check' },
        rowz:  { implemented: false, description: 'Read-only, value is cleared on read' }
      }

      # Returns the Reg object that owns the bit
      attr_reader :owner
      # Returns the integer position of the bit within the register
      attr_reader :position
      # Current the data value currently held by the bit, 0 or 1
      attr_reader :data
      # Returns any overlay string attached to the bit
      attr_reader :overlay
      # If the bit does not read back with the same data as is written to it
      # then this will return true. This property can be assigned durgin the
      # register instantiation, e.g.
      #   add_reg :control,    0x00,    :mode    => { :pos => 8, :bits => 8 },
      #                                 :status  => { :pos => 4, :bits => 2, :read_data_matches_write => false }
      attr_reader :read_data_matches_write
      # Returns true if this bit has the sticky_overlay flag set, see Reg#sticky_overlay for
      # a full description. This is true by default.
      attr_accessor :sticky_overlay
      # Returns true if this bit has the sticky_store flag set, see Reg#sticky_store for
      # a full description. This is false by default.
      attr_accessor :sticky_store
      # Any feature associated with the bit/bits
      attr_reader :feature
      # Returns the reset value of the bit
      attr_accessor :reset_val
      alias_method :reset_data, :reset_val
      alias_method :reset_value, :reset_val
      # Allow modify of writable flag, bit is writeable by write method
      attr_writer :writable
      # Allow modify of readable flag, bit is readable by read method
      attr_writer :readable
      # Sets or returns the status of "write-one-to-clear"
      attr_accessor :w1c
      # Allow modify of clr_only flag, bit can only be cleared (made 0)
      attr_writer :clr_only
      # Allow modify of set_only flag, bit can only be set (made 1)
      attr_writer :set_only
      # Returns true if bit depends on initial state of NVM in some way
      attr_reader :nvm_dep
      # Returns true if bit is critical to starting an important operation (like a state machine)
      # so that it can be made not writable during basic register checks
      attr_reader :start
      # Returns any application-specific meta-data attatched to the given bit
      attr_accessor :meta
      alias_method :meta_data, :meta
      alias_method :metadata, :meta
      # Returns the access method for the given bit (a symbol), see the ACCESS_CODES constant for
      # the possible values this can have and their meaning
      attr_accessor :access

      def initialize(owner, position, options = {}) # rubocop:disable MethodLength
        options = {
          start:                   false,        # whether bit starts a state machine so be careful
          read_data_matches_write: true,
          read:                    false,
          overlay:                 false,
          store:                   false,
          sticky_overlay:          true,
          sticky_store:            false,
          nvm_dep:                 false,        # whether is an NVM dependent bit
        }.merge(options)
        @owner = owner
        @position = position
        @undefined = options.delete(:undefined)
        @reset_val = (options.delete(:res) || options.delete(:reset) || options.delete(:data) || 0)
        if @reset_val.is_a?(Symbol)
          @data = 0
        else
          @reset_val &= 1 unless @reset_val.is_a?(Symbol)
          @data = @reset_val
        end

        access_code = options.delete(:access)
        # If access has been defined then none of these other attributes can be
        if access_code
          conflicts = [:readable, :writable, :clr_only, :set_only, :w1c]
          if conflicts.any? { |k| options.key?(k) }
            puts 'The following attributes cannot be set in combination with :access'
            puts "  #{conflicts.join(', ')}"
            puts ''
            puts 'Use :access to defined the required behavior, the above attributes will be deprecated in future.'
            puts ''
            fail 'Conflicting access!'
          end
          set_access(access_code)
        else
          options = {
            writable: true,         # whether bit is writable
            readable: true,         # whether bit is readable
            clr_only: false,        # whether bit is clear only
            set_only: false,        # whether bit is set only
            w1c:      false,        # whether bit is w1c (when written to 1 immediately becomes 0)
          }.merge(options)
          @readable = options.delete(:readable)
          @writable = options.delete(:writable)
          @clr_only = options.delete(:clr_only)
          @set_only = options.delete(:set_only)
          @w1c = options.delete(:w1c)
          set_access_from_rw
        end
        # Would like to get this integrated with access as well
        @read_data_matches_write = options.delete(:read_data_matches_write)

        @feature = options.delete(:feature)
        if !!feature && @writable
          @writable = enabled?
        end
        @path     = options.delete(:path)
        @abs_path = options.delete(:abs_path)
        @start = options.delete(:start)
        @read = options.delete(:read)
        @overlay = options.delete(:overlay)
        @store = options.delete(:store)
        @update_required = false
        @sticky_store = options.delete(:sticky_store)
        @sticky_overlay = options.delete(:sticky_overlay)
        @nvm_dep = (options.delete(:nvm_dep) ? 1 : 0)
        # Delete some other noise that can be left over...
        options.delete(:bits)
        options.delete(:pos)
        options.delete(:position)
        options.delete(:data)
        # Whatever is left must be custom application meta-data
        @meta = (default_bit_metadata).merge(options)
      end

      def set_access(value)
        unless ACCESS_CODES.keys.include?(value)
          puts 'Invalid access code, must be one of these:'
          ACCESS_CODES.each do |code, meta|
            puts "  :#{code}".ljust(10) + " - #{meta[:description]}"
          end
          puts ''
          fail 'Invalid access code!'
        end
        @access = value

        # Set readable & writable based on access
        if @access == :ro
          @readable = true
          @writable = false
        elsif @access == :wo || @access == :worz
          @writable = true
          @readable = false
        elsif @access == :w1c
          @w1c = true
          @writable = true
          @readable = true  # Is this always valid?
        elsif @access == :wc
          @clr_only = true
          @writable = true
          @readable = true  # Is this always valid?
        elsif @access == :ws
          @set_only = true
          @writable = true
          @readable = true  # Is this always valid?
        # Catch all for now until the behavior of this class is based around @access
        else
          @writable = true
          @readable = true
        end
      end

      # Set @access based on @readable and @writable
      def set_access_from_rw
        if @w1c
          @access = :w1c
        elsif @clr_only
          @access = :wc
        elsif @set_only
          @access = :ws
        elsif @readable && @writable
          @access = :rw
        elsif @readable
          @access = :ro
        elsif @writable && @access != :worz
          @access = :wo
        end
      end

      def path_var
        @path
      end

      def abs_path
        @abs_path
      end

      ACCESS_CODES.each do |code, _meta|
        define_method "#{code}?" do
          !!(access == code || instance_variable_get("@#{code}"))
        end
      end

      # Returns any application specific metadata that has been inherited by the
      # given bit.
      # This does not account for any overridding that may have been applied to
      # this bit specifically however, use the meta method to get that.
      def default_bit_metadata
        Origen::Registers.default_bit_metadata.merge(
          Origen::Registers.bit_metadata[owner.owner.class] || {})
      end

      def inspect
        "<#{self.class}:#{object_id}>"
      end

      # Always returns 1 when asked for size, a BitCollection on the other hand will return something higher
      def size
        1
      end

      # Make this bit disappear, make it unwritable with a data value of 0
      def delete
        @sticky_overlay = false
        @sticky_store = false
        clear_flags
        @data = 0
        @writable = false
        self
      end

      # Returns true if the bit is set (holds a data value of 1)
      def set?
        @data == 1 ? true : false
      end

      # Resets the data value back to the reset value and calls Bit#clear_flags
      def reset
        if @reset_val.is_a?(Symbol)
          @data = 0
        else
          @data = @reset_val
        end
        @updated_post_reset = false
        clear_flags
        self
      end

      # Returns true if the bit object is a placeholder for bit positions that have
      # not been defined within the parent register
      def undefined?
        @undefined
      end

      # Returns true if the value of the bit is known. The value will be
      # unknown in cases where the reset value is undefined or determined by a memory location
      # and where the bit has not been written or read to a specific value yet.
      def has_known_value?
        !@reset_val.is_a?(Symbol) || @updated_post_reset
      end

      # Set the data value of the bit to the given value (1 or 0)
      # If the bit is read-only, the value of the bit can be forced with 'force: true'
      def write(value, options = {})
        # If an array is written it means a data value and an overlay have been supplied
        # in one go...
        if value.is_a?(Array)
          overlay(value[1])
          value = value[0]
        end
        if (@data != value & 1 && @writable) ||
           (@data != value & 1 && options[:force] == true)
          if ((set?) && (!@set_only)) ||
             ((!set?) && (!@clr_only))
            @data = value & 1
            @update_required = true
            @updated_post_reset = true
          end
        end
        self
      end

      # Will tag all bits for read and if a data value is supplied it
      # will update the expected data for when the read is performed.
      def read(value = nil, _options = {})
        # First properly assign the args if value is absent...
        if value.is_a?(Hash)
          options = value
          value = nil
        end
        write(value) if value
        @read = true if @readable && @read_data_matches_write
        self
      end

      # Sets the store flag attribute
      def store
        @store = true
        self
      end

      # Set the overlay attribute to the supplied value
      def overlay(value)
        @overlay = value
        self
      end

      # Returns the overlay attribute
      def overlay_str
        @overlay
      end

      # Returns true if the bit's read flag is set
      def is_to_be_read?
        @read
      end

      # Returns true if the bit's store flag is set
      def is_to_be_stored?
        @store
      end

      # Returns true if the overlay attribute is set, optionally supply an overlay
      # name and this will only return true if the overlay attribute matches that name
      def has_overlay?(name = nil)
        if name
          name.to_s == @overlay.to_s
        else
          !!@overlay
        end
      end

      # Returns true if the bit is writable
      def is_writable?
        @writable
      end
      alias_method :writable?, :is_writable?

      def is_readable?
        @readable
      end
      alias_method :readable?, :is_readable?

      # Clears the read, store, overlay and update_required flags of this bit.
      # The store and overlay flags will not be cleared if the the bit's sticky_store
      # or sticky_overlay attributes are set respectively.
      def clear_flags
        @read = false
        @store = false unless @sticky_store
        @overlay = false unless @sticky_overlay
        @update_required = false
        self
      end

      # Clears the read flag of this bit.
      def clear_read_flag
        @read = false
        self
      end

      # Returns a bit mask for this bit, that is a 1 shifted into the position
      # corresponding to this bit's position. e.g. A bit with position 4 would return
      # %1_0000
      def mask
        mask_val = 1
        mask_val << @position
      end

      # Returns a 'null' bit object which has value 0 and no other attributes set
      def self.null(owner, position) # :nodoc:
        Bit.new(owner, position, writable: false)
      end

      # Returns the value you would need to write to the register to put the given
      # value in this bit
      def setting(value)
        value = value & 1   # As this bit can only hold one bit of data force it
        value << @position
      end

      # Returns true if the bit's update_required flag is set, typically this will be the
      # case when a write has changed the data value of the bit but a BitCollection#write!
      # method has not been called yet to apply it to silicon
      def update_required?
        @update_required
      end

      # With only one bit it just returns itself
      def shift_out_left
        yield self
      end

      # Returns the data shifted by the bit position
      def data_in_position
        data << position
      end

      # Clears any w1c bits that are set
      def clear_w1c
        if @w1c && set?
          @data = 0
        end
        self
      end

      # Clears any start bits that are set
      def clear_start
        if @start && set?
          @data = 0
        end
        self
      end

      def respond_to?(sym) # :nodoc:
        meta_data_method?(sym) || super(sym)
      end

      # @api private
      def meta_data_method?(method)
        attr_name = method.to_s.gsub(/\??=?/, '').to_sym
        if default_bit_metadata.key?(attr_name)
          if method.to_s =~ /\?/
            [true, false].include?(default_bit_metadata[attr_name])
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

      def method_missing(method, *args, &block) # :nodoc:
        if meta_data_method?(method)
          extract_meta_data(method, *args)
        else
          super
        end
      end

      # Returns true if the bit is constrained by the given/any feature
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
            feature == name
          end
        end
      end
      alias_method :has_feature_constraint?, :enabled_by_feature?

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
    end
  end
end
