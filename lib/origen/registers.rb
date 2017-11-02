module Origen
  # Origen provides a powerful register class which you are encouraged to use when
  # you wish to interact with a silicon register (or RAM location).
  # By interacting with the register on silicon through the register API your
  # pattern will automatically track silicon state, so you can set and forget
  # bits in the patgen the same as you would do with a physical register.
  # Include this module to add registers to your block, then use the macros described
  # below to instantiate register objects
  #   include Origen::Registers
  module Registers
    extend ActiveSupport::Concern

    autoload :Container,     'origen/registers/container'
    autoload :Reg,           'origen/registers/reg'
    autoload :Bit,           'origen/registers/bit'
    autoload :BitCollection, 'origen/registers/bit_collection'
    autoload :RegCollection, 'origen/registers/reg_collection'
    autoload :Domain,        'origen/registers/domain'

    included do
      include Origen::ModelInitializer
      include Origen::SubBlocks
      include Origen::Callbacks  # Required for global register reset

      attr_accessor :owner
      attr_accessor :name
      attr_writer :bit_order
    end

    # Returns the bit order attribute of the model (either :msb0 or :lsb0). If
    # not explicitly defined on this model it will be inherited from the parent
    # and will default to :lsb0 at the top-level
    def bit_order
      @bit_order ||= begin
        if parent
          parent.bit_order
        else
          :lsb0
        end
      end
    end

    def method_missing(method, *args, &block) # :nodoc:
      orig_method = method
      if method[-1] == '!'
        bang = true
        method = method.to_s.chop.to_sym
      end
      if _registers.key?(method)
        r = reg(method)
        r.sync if bang
        r
      else
        super(orig_method, *args, &block)
      end
    end

    def respond_to?(sym, include_private = false) # :nodoc:
      if sym[-1] == '!'
        r = sym.to_s.chop.to_sym
        _registers.key?(r) || super(sym)
      else
        _registers.key?(sym) || super(sym)
      end
    end

    def delete_registers
      @_registers = nil
    end

    # Class methods of this module
    class << self
      @@reg_metadata = {}
      @@bit_metadata = {}

      # @api private
      # Returns a lookup table containing all custom register metadata
      # defined by objects in an application
      def reg_metadata
        @@reg_metadata ||= {}
      end

      # @api private
      # Returns a lookup table containing all custom bit metadata
      # defined by objects in an application
      def bit_metadata
        @@bit_metadata ||= {}
      end

      # Can be called to add app specific meta data to all registers
      def default_reg_metadata
        Origen::Registers.reg_metadata[:global] ||= {}
        if block_given?
          collector = Collector.new
          yield collector
          Origen::Registers.reg_metadata[:global].merge!(collector.store)
        end
        Origen::Registers.reg_metadata[:global]
      end

      # An alias for default_reg_metadata
      def default_reg_meta_data(*args, &block)
        default_reg_metadata(*args, &block)
      end

      # Can be called to add app specific meta data to all bits
      def default_bit_metadata
        Origen::Registers.bit_metadata[:global] ||= {}
        if block_given?
          collector = Collector.new
          yield collector
          Origen::Registers.bit_metadata[:global].merge!(collector.store)
        end
        Origen::Registers.bit_metadata[:global]
      end

      # An alias for default_bit_metadata
      def default_bit_meta_data(*args, &block)
        default_bit_metadata(*args, &block)
      end
    end

    # All register objects are stored here, but they should be accessed
    # via the _reg method to ensure that feature scoping is applied
    #
    # @api private
    def _registers
      @_registers ||= RegCollection.new(self)
    end

    # Instantiating registers can be quite expensive, this object is a placeholder
    # for a register and will transform into one automatically when it is required to
    # (i.e. whenever a register method is called on it).
    class Placeholder
      attr_reader :name, :owner, :attributes, :feature
      alias_method :id, :name

      def initialize(owner, name, attributes)
        @owner = owner
        @name = name
        @attributes = attributes
        @feature = attributes[:feature] if attributes.key?(:feature)
      end

      # Make this appear like a reg to any application code
      def is_a?(klass)
        klass == Origen::Registers::Reg ||
          klass == self.class
      end

      # Returns true if the register is enabled by a feature of owner.
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

      # Make it look like a reg in the console to avoid confusion
      def inspect
        materialize.inspect
      end

      # Don't need to act on reset, an un-materialized reg is by default already reset
      def reset
      end

      def freeze
        materialize.freeze
      end

      def method_missing(method, *args, &block)
        materialize.send(method, *args, &block)
      end

      def respond_to?(method, include_private = false)
        materialize.respond_to?(method, include_private)
      end

      def materialize
        owner.instantiate_reg(name, attributes)
      end

      def clone
        materialize.clone
      end

      def dup
        materialize.dup
      end

      def contains_bits?
        true
      end

      def to_json(*args)
        materialize.to_json(*args)
      end
    end

    class Collector
      attr_reader :store

      def initialize
        @store = {}
      end

      def method_missing(method, *args, &_block)
        @store[method.to_s.sub('=', '').to_sym] = args.first
      end
    end

    # Returns true if the given object is one of the recognized Origen
    # bit containers (bit collection, reg or container).
    def contains_bits?(obj)
      obj.respond_to?(:contains_bits?) && obj.contains_bits?
    end

    # Returns true if the given object is an Origen bit
    def is_a_bit?(obj)
      obj.is_a?(Origen::Registers::Bit)
    end

    # Add a register.
    # When adding a register you must supply a name, an address, size in bits, and bit definitions,
    # any bits that are not declared will be filled with dummy bit objects that are
    # not writable and will read back as 0.
    #
    # @example
    #             Name    Address  Size   Bit Definitions
    #   add_reg :control,  0x00,    16    :mode    => { :pos => 8, :bits => 8 },
    #                                     # Leaving out bits does 1 by default
    #                                     :launch  => { :pos => 6 },
    #                                     # The default reset state is 0, specify an alternative..
    #                                     :status  => { :pos => 4, :bits => 2, :res => 0b11 },
    #                                     :fail    => { :pos => 2 },
    #                                     :done    => { :pos => 0 }
    #
    # Can be called on any object to add a register to it
    def add_reg(id, address, size = nil, bit_info = {}, &_block)
      if address.is_a?(Hash)
        fail 'add_reg requires the address to be supplied as the 2nd argument, e.g. add_reg :my_reg, 0x1000'
      end
      size, bit_info = nil, size if size.is_a?(Hash)
      size ||= bit_info.delete(:size) || 32
      description = bit_info.delete(:description)

      local_vars = {}

      Reg::REG_LEVEL_ATTRIBUTES.each do |attribute, meta|
        aliases = [attribute]
        aliases += meta[:aliases] if meta[:aliases]
        aliases.each { |_a| local_vars[attribute] = bit_info.delete(attribute) if bit_info.key?(attribute) }
      end

      local_vars[:reset] ||= :memory if local_vars[:memory]
      @min_reg_address ||= address
      @max_reg_address ||= address
      # Must set an initial value, otherwise max_address_reg_size will be nil if a sub_block contains only
      # a single register.
      @max_address_reg_size = size unless @max_address_reg_size
      @min_reg_address = address if address < @min_reg_address
      if address > @max_reg_address
        @max_address_reg_size = size
        @max_reg_address = address
      end
      @reg_define_file ||= define_file(caller[0])

      if block_given?
        @new_reg_attrs = { meta: bit_info }
        yield self
        bit_info = @new_reg_attrs
      else
        # If no block given then init with all writable bits unless bit_info has
        # been supplied
        unless bit_info.any? { |k, v| v.is_a?(Hash) && v[:pos] }
          bit_info = { d: { pos: 0, bits: size }.merge(bit_info) }
        end
      end
      if _registers[id] && Origen.config.strict_errors
        puts ''
        puts "Add register error, you have already added a register named #{id} to #{self.class}"
        puts ''
        fail 'Duplicate register error!'
      else
        attributes = {
          define_file: @reg_define_file,
          address:     address,
          size:        size,
          bit_info:    bit_info,
          description: description
        }
        Reg::REG_LEVEL_ATTRIBUTES.each do |attribute, _meta|
          attributes[attribute] = local_vars[attribute]
        end
        _registers[id] = Placeholder.new(self, id, attributes)
      end
      @reg_define_file = nil
    end

    # Delete an existing register
    def del_reg(id)
      _registers.delete(id)
    end

    # @api private
    def define_file(file)
      if Origen.running_on_windows?
        fields = file.split(':')
        "#{fields[0]}:#{fields[1]}"
      else
        file.split(':').first
      end
    end

    # Called within an add_reg block to define bits
    def bit(index, name, attrs = {})
      if index.is_a?(Range)
        msb = index.first
        lsb = index.last
        msb, lsb = lsb, msb if lsb > msb
        pos = lsb
        bits = (msb - lsb).abs + 1
      elsif index.is_a?(Numeric)
        pos = index
        bits = 1
      else
        fail 'No valid index supplied when defining a register bit!'
      end

      # Traynor, this could be more elegant
      # its just a dirty way to make the value of the
      # key in @new_reg_atts hash array (ie name) tie to
      # a value that is an array of hashes describing
      # data for each scrambled bit
      attrs = attrs.merge(pos: pos, bits: bits)
      temparray = []
      if @new_reg_attrs[name].nil?
        @new_reg_attrs[name] = attrs
      else
        if @new_reg_attrs[name].is_a? Hash
          temparray = temparray.push(@new_reg_attrs[name])
        else
          temparray = @new_reg_attrs[name]
        end
        temparray = temparray.push(attrs)
        # added the sort so that the order the registers bits is described is not important
        @new_reg_attrs[name] = temparray.sort { |a, b| b[:pos] <=> a[:pos] }

      end
    end

    alias_method :bits, :bit

    # Can be called to add app specific meta data that is isolated to all registers
    # defined within a given class
    def default_reg_metadata
      Origen::Registers.reg_metadata[self.class] ||= {}
      if block_given?
        collector = Collector.new
        yield collector
        Origen::Registers.reg_metadata[self.class].merge!(collector.store)
      end
      Origen::Registers.reg_metadata[self.class]
    end
    alias_method :default_reg_meta_data, :default_reg_metadata

    def default_bit_metadata
      Origen::Registers.bit_metadata[self.class] ||= {}
      if block_given?
        collector = Collector.new
        yield collector
        Origen::Registers.bit_metadata[self.class].merge!(collector.store)
      end
      Origen::Registers.bit_metadata[self.class]
    end
    alias_method :default_bit_meta_data, :default_bit_metadata

    # @api private
    def instantiate_reg(id, attrs)
      return _registers[id] unless _registers[id].is_a?(Origen::Registers::Placeholder)
      attributes = {
        define_file: attrs[:define_file],
        description: attrs[:description]
      }
      Reg::REG_LEVEL_ATTRIBUTES.each do |attribute, _meta|
        attributes[attribute] = attrs[attribute]
      end
      _registers[id] = Reg.new(self, attrs[:address], attrs[:size], id,
                               attrs[:bit_info].merge(attributes))
    end

    def add_reg32(id, address, args = {}, &block)
      @reg_define_file = define_file(caller[0])
      add_reg(id, address, 32, args, &block)
    end

    # Returns the lowest address of all registers that have been added
    def min_reg_address
      @min_reg_address || 0
    end

    # Returns the highest address of all registers that have been added
    def max_reg_address
      @max_reg_address || 0
    end

    # Returns the size (in bits) of the register with the highest address,
    # can be useful in combination with max_reg_address to work out the
    # range of addresses containing registers
    def max_address_reg_size
      @max_address_reg_size
    end

    # Resets all registers
    def reset_registers
      regs.each { |_name, reg| reg.reset }
    end

    # Returns true if the object contains a register matching the given name
    def has_reg?(name, params = {})
      params = {
        test_for_true_false: true
      }.update(params)
      if params.key?(:enabled_features) || params.key?(:enabled_feature)
        return !!get_registers(params).include?(name)
      else
        params[:enabled_features] = :default
        return !!get_registers(params).include?(name)
      end
    end
    alias_method :has_reg, :has_reg?

    # Returns
    #  -the register object matching the given name
    #  -or a hash of all registes matching a given regular expression
    #  -or a hash of all registers, associated with a feature, if no name is specified.
    #
    # Can also be used to define a new register if a block is supplied in which case
    # it is equivalent to calling add_reg with a block.
    def reg(*args, &block)
      if block_given? || (args[1].is_a?(Fixnum) && !try(:_initialized?))
        @reg_define_file = define_file(caller[0])
        add_reg(*args, &block)
      else
        # Example use cases:
        # reg(:reg2)
        # reg(:name => :reg2)
        # reg('/reg2/')
        if !args.empty? && args.size == 1 && (args[0].class != Hash || (args[0].key?(:name) && args[0].size == 1))
          if args[0].class == Hash
            name = args[0][:name]
          else name = args.first
          end
          if has_reg(name)
            return _registers[name]
          elsif name =~ /\/(.+)\//
            regex = Regexp.last_match(1)
            return match_registers(regex)
          else
            if Origen.config.strict_errors
              puts ''
              if regs.empty?
                puts "#{self.class} does not have a register named #{name} or it is not enabled."
              else
                puts "#{self.class} does not have a register named #{name} or it is not enabled."
                puts 'You may need to add it. This could also be a typo, these are the valid register names:'
                puts regs.keys
              end
              puts ''
              fail 'Missing register error!'
            end
          end
        # Example use cases:
        # reg(:enabled_features => :all)
        # reg(:name => :reg2, enabled_features => :all)
        # reg(:name => :reg2, enabled_features => :fac)
        elsif !args.empty? && args.size == 1 && args[0].class == Hash
          params = args[0]

          # Example use case:
          # reg(:name => :reg2, :enabled_features => :all)
          if (params.key?(:enabled_features) || params.key?(:enabled_feature)) && params.key?(:name)
            name = params[:name]
            if has_reg(name, params)
              _registers[name]
            else
              reg_missing_error(params)
            end
          # Example use case:
          # reg(:enabled_features =>[:fac, fac2])
          elsif params.size == 1 && params.key?(:enabled_features)
            return get_registers(enabled_features: params[:enabled_features])
          end

        # Example use case:
        # reg(:reg2, :enabled_features => :all)
        # reg(:reg2, :enabled_features => :default)
        # reg(:reg2, :enabled_features => :fac)
        elsif !args.empty? && args.size == 2
          name = args[0]
          params = args[1]
          name, params = params, name if name.class == Hash
          if has_reg(name, params)
            _registers[name]
          else
            reg_missing_error(params)
          end
        elsif args.empty?
          if _registers.empty?
            return _registers
          else
            return get_registers(enabled_features: :default)
          end
        else
          if Origen.config.strict_errors
            fail 'Invalid call to reg method or invalid arguments specified'
          end
        end
      end
    end
    alias_method :regs, :reg

    private

    def match_registers(regex)
      regs_to_return = RegCollection.new(self)
      _registers.each do |k, v|
        regs_to_return[k] = v if k.to_s.match(/#{regex}/)
      end
      regs_to_return
    end
    alias_method :regs_match, :match_registers

    def reg_missing_error(params)
      if Origen.config.strict_errors
        puts ''
        temp = regs(params)
        if temp.empty?
          puts "#{self.class} does not have a register named #{name} within the supplied feature scope, you need to add it."
        else
          puts "#{self.class} does not have a register named #{name} within the supplied feature scope, you may need to add it."
          puts 'This could also be a typo, these are the valid register names:'
          puts temp.keys
        end
        puts ''
        fail 'Missing register error!'
      end
    end

    def extract_enabled_features(options)
      options[:enabled_features] || options[:enabled_feature]
    end

    def get_registers(params)
      params = {
        test_for_true_false: false
      }.update(params)
      regs_to_return = RegCollection.new(self)
      req_features = extract_enabled_features(params)
      if req_features == :all
        regs_to_return = _registers
      elsif req_features == :none
        _registers.each do |k, v|
          regs_to_return[k] = v unless v.has_feature_constraint?
        end
      elsif req_features == :default
        _registers.each do |k, v|
          regs_to_return[k] = v if v.enabled?
        end
      elsif req_features.class == Array
        req_features.each do |req_feat|
          _registers.each do |k, v|
            regs_to_return[k] = v if v.enabled_by_feature?(req_feat) || !v.has_feature_constraint?
          end
        end
      else
        _registers.each do |k, v|
          regs_to_return[k] = v if v.enabled_by_feature?(req_features) || !v.has_feature_constraint?
        end
      end
      if regs_to_return.empty?
        unless params[:test_for_true_false]
          puts 'No register found with the specified feature or the register is disabled!'
          fail 'Missing register error!'
        end
      end
      regs_to_return
    end

    public

    # Creates a dummy register. Equivalent to Reg.dummy except the reg owner is assigned
    # as the caller rather than Reg. Use this if you need to call read! or write! on the
    # dummy register object.
    def dummy_reg(size = 16)
      Reg.new(self, 0, size, :dummy, init_as_writable: true)
    end

    def write_register_missing!(reg)
      klass = (try(:controller) || self).class
      puts ''
      puts ''
      puts <<-EOT
You have made a request to write register: #{reg.name}, however the #{klass}
class does not know how to do this yet. You should implement a write_register
method in the #{klass} like this:

  def write_register(reg, options={})
    <logic to handle the writing of the reg object here>
  end
      EOT
      puts ''
      exit 1
    end

    def read_register_missing!(reg)
      klass = (try(:controller) || self).class
      puts ''
      puts ''
      puts <<-EOT
You have made a request to read register: #{reg.name}, however the #{klass}
class does not know how to do this yet. You should implement a read_register
method in the #{klass} like this:

  def read_register(reg, options={})
    <logic to handle reading the reg object here>
  end
      EOT
      puts ''
      exit 1
    end
  end
end
