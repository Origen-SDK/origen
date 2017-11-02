module Origen
  # ****** These notes refer to the pin model for the upcoming Origen V3 ******
  #
  # Pin muxing and grouping on modern SoCs can be incredibly complex, Origen provides the following pin model
  # architecture which should hopefully be sufficient to accurately model even the most complex of cases...
  #
  # At the lowest layer are the pin objects, one per physical pin on a DUT. Each pin can store 1-bit of data
  # with directional/state information for pattern generation, and additional metadata about the function of
  # that pin in different modes of operation.
  #
  #     pin1                        pin2                        pin3                        pin4
  #
  # *Package*
  #
  # Packages are the first layer of filtering that can be applied to pins, each pin has a package hash which
  # contains information about which packages it is available in and any additional metadata associated with
  # the pin when in that package - for example what package pin location it is.
  #
  #     pin1                        pin2                        pin3                        pin4
  #       packages:                   packages:                   packages:                   packages:
  #         p1:                         p1:                         p1:
  #           location: "A5"              location: "B2"              location: "B3"
  #         p2:                                                     p2:
  #           location: "A5"                                          location: "B2"
  #
  # Based on the above metadata these pins will work as follows within an SoC model:
  #
  #     $dut.package                     # => :none
  #     $dut.pins.size                   # => 4
  #
  #     $dut.with_package :p1 do
  #       $dut.pins.size                 # => 3     (No pin4)
  #       $dut.pin(:pin1).location       # => "A5"
  #       $dut.has_pin?(:pin2)           # => true
  #       $dut.pin(:pin2).location       # => "B2"
  #       $dut.pin(:pin3).location       # => "B3"
  #     end
  #
  #     $dut.with_package :p2 do
  #       $dut.pins.size                 # => 2     (No pin2 or pin4)
  #       $dut.pin(:pin1).location       # => "A5"
  #       $dut.has_pin?(:pin2)           # => false
  #       $dut.pin(:pin2).location       # => ERROR! The soc does not have pin 2 in the current configuration!
  #       $dut.pin(:pin3).location       # => "B2"
  #     end
  #
  # Aside from a physical package the packages attribute can also be used to model pseudo-packages like the
  # subset of pins that are available in a probe or burn-in setup for example.
  #
  # Pins availability can also be scoped by SoC mode and configuration...
  #
  # *Mode*
  #
  # The SoC mode attribute is inteded to be used to model top-level operating modes, such as functional test,
  # RAMBIST, NVMBIST, etc. As such it is a top-level attribute similar to package attribute e.g. the SoC can be
  # in RAMBIST mode within package P1, or it could be in User mode within package P2.
  #
  # *Configuration*
  #
  # The configuration scope should be used to model pin muxing that can occur independently of the SoC mode, for
  # example in a functional test mode many different pin configurations may exist based on the IP modules that
  # are enabled or disabled at runtime.
  # Unlike the mode the configuration attribute can also be set at pin level as well. Any configuration attribute
  # set on a pin will override the configuration attribute that is currently live on the SoC. This allows individual
  # pins, or perhaps more commonly individual pin groups, to be set to a particular configuration independently
  # of the other pins or the SoC.
  #
  # The mode and configuration attributes at pin level are similar to those for the package, each pin also has a
  # current_configuration attribute which will override the current_configuration attribute of the SoC when
  # present. Each mode and configuration entry will be hash for storing meta data as required.
  #
  #     pin1                        pin2                        pin3                        pin4
  #       modes:                      modes:                      modes:                      modes:
  #         user:                       user:                       user:
  #         nvmbist:                    nvmbist:
  #       configurations:             configurations:             configurations:             configurations:
  #         default:                    default:                    default:                    default:
  #         alt0:                       alt1:                       alt0:
  #                                                                 alt1:
  #
  # Pin availability will be scoped accordingly when the mode and configuration of the SoC model is changed.
  #
  # Although not shown in this example all of these filters are AND'd together, so a pin is only available if it
  # is available in the current package, mode and configuration.
  #
  #     $dut.mode                        # => :none
  #     $dut.configuration               # => :none
  #
  #     $dut.pins.size                   # => 4
  #     $dut.mode = :user
  #     $dut.pins.size                   # => 3   (No pin4)
  #
  #     $dut.configuration = :alt0
  #     $dut.pins.size                   # => 2   (No pin2 or pin4)
  #     # Set the configuration of pin2 directly, the all_pins method will bypass the current scope
  #     # when looking up a pin
  #     $dut.all_pins(:pin2).configuration = :alt1
  #     $dut.pins.size                   # => 3   (pin2 is now available to)
  #
  # While not shown here an additional value of :all can be set when specifying the mode/configuration attributes
  # of a given pin and which means that it will be available in all modes and/or configurations.
  #
  # *Functions*
  #
  # Each pin can have multiple functions associated with it which is intended to reflect the current signal that is
  # mux'd onto it. Functions are scoped by mode and configuration (not package) and only one function can exist
  # per mode/configuration combo.
  #
  # Again the reserved mode/configuration name :all can be used here to reflect a function that will be common to
  # all modes/configurations unless a more specific function has been declared.
  # The top-level key of the functions hash is the mode, then the configuration and then the meta data associated
  # with that selection:
  #
  #     pin1                        pin2                        pin3                        pin4
  #       functions:                  functions:                  functions:                  functions:
  #         user:                       user:                       user:
  #           all:                        default:                    default:
  #             name: "TDI"                  name: "PORTA0"              name: "PORTA1"
  #             direction: :input            direction: :io              direction: :io
  #                                       alt1:                       alt0:
  #                                          name: "SPI0"                name: "IIC0"
  #                                          direction: :io              direction: :output
  #                                                                   alt1:
  #                                                                      name: "SPI1"
  #                                                                      direction: :io
  #         nvmbist:                    nvmbist:
  #           all:                        all:
  #             name: "NVM_FAIL"            name: "NVM_DONE"
  #             direction: :output          direction: :output
  #
  # The function attributes returned will automatically scope to the current SoC state:
  #
  #     $dut.mode = :user
  #     $dut.pin(:pin1).name             # => "TDI"
  #     $dut.pin(:pin1).direction        # => :input
  #
  #     $dut.mode = :nvmbist
  #     $dut.pin(:pin1).name             # => "NVM_FAIL"
  #     $dut.pin(:pin1).direction        # => :output
  #
  # *Aliases*
  #
  # Aliases are alternative names/handles to give to pins when using them to create patterns and other IP in Origen.
  # Aliases can be made universal in which case they will work regardless of scope, or they can be scoped to the
  # current package, mode and configuration.
  #
  # The Origen pin API will automatically create scoped aliases for functions and package locations as they are
  # declared, so for example:
  #
  #     $dut.mode = :user
  #     $dut.pin(:pin1).name             # => "TDI"
  #     $dut.pin(:tdi).name              # => "TDI"
  #     $dut.has_pin?(:nvm_fail)         # => false
  #     $dut.pin(:nvm_fail).name         # => ERROR! No pin called NVM_FAIL in the current scope!
  #
  #     $dut.mode = :nvmbist
  #     $dut.pin(:pin1).name             # => "NVM_FAIL"
  #     $dut.has_pin?(:nvm_fail)         # => true
  #     $dut.pin(:nvm_fail).name         # => "NVM_FAIL"
  #
  #
  # *Pin Groups*
  #
  # Pin groups will be similar to aliases in that they can be made universal or scoped to a specific package/mode/
  # configuration.
  #
  # While aliases are simply pointers to pin objects pin groups will themselves be an Origen object which will be like
  # a Ruby array with additional metadata attached (such as a name) and a dedicated API for working with the pins.
  # Generally a pin and pingroup will respond to the same API so that calling code does not need to worry very much
  # about dealing with a single pin vs. a collection.
  module Pins
    autoload :Pin,           'origen/pins/pin'
    autoload :PinCollection, 'origen/pins/pin_collection'
    autoload :PinBank,       'origen/pins/pin_bank'
    autoload :PinCommon,     'origen/pins/pin_common'
    autoload :PinClock,      'origen/pins/pin_clock'
    autoload :PowerPin,      'origen/pins/power_pin'
    autoload :GroundPin,     'origen/pins/ground_pin'
    autoload :OtherPin,      'origen/pins/other_pin'
    autoload :VirtualPin,    'origen/pins/virtual_pin'
    autoload :FunctionProxy, 'origen/pins/function_proxy'
    require 'origen/pins/timing'

    include Timing

    # @api private
    # API v2, deprecated
    def self.clear_pin_aliases
      @@pin_aliases = {}
    end

    # @api private
    #
    # Aliases are stored in a global array that is cleared out everytime the target is loaded,
    # while a bit hacky this is an easy way to allow sub modules to defined con
    #
    # API v2, deprecated
    def self.pin_aliases
      @@pin_aliases ||= {}
    end

    # Use this method to add any pins that are considered owned by the given object.
    # Pins declared via this method will be accessible within the object via
    # pin(:pinname) or if you prefer self.pin(:pinname). Externally you would refer
    # to it via $top.pin(:pinname) or $soc.pin(:pinname) or even
    # $top.sub_module.pin(:pinname) depending on where you called this method.
    # Pins are output in the pattern in the order that they are declared.
    # A minimum declaration is this:
    #   add_pin  :d_out        # A single pin that will be set to :dont_care by default
    # To set the initial state at the same time:
    #   add_pin  :d_in,   :reset => :drive_hi
    #   add_pin  :invoke, :reset => :drive_lo
    # You can override the name that appears in the pattern by providing a string
    # as the last argument
    #   add_pin  :done,   :reset => :expect_hi, :name => "bist_done"
    #   add_pin  :fail,                         :name => "bist_fail"
    def add_pin(id = nil, options = {}, &_block)
      id, options = nil, id if id.is_a?(Hash)
      power_pin = options.delete(:power_pin)
      ground_pin = options.delete(:ground_pin)
      virtual_pin = options.delete(:virtual_pin)
      other_pin = options.delete(:other_pin)
      if options[:size] && options[:size] > 1
        group = PinCollection.new(self, options.merge(placeholder: true))
        group.id = id if id
        options = {
          name: ''
        }.merge(options)

        options.delete(:size).times do |i|
          options[:name] = "#{id}#{i}".to_sym

          if power_pin
            group[i] = PowerPin.new(i, self, options)
          elsif ground_pin
            group[i] = GroundPin.new(i, self, options)
          elsif virtual_pin
            group[i] = VirtualPin.new(i, self, options)
          elsif other_pin
            group[i] = OtherPin.new(i, self, options)
          else
            group[i] = Pin.new(i, self, options)
          end
          group[i].invalidate_group_cache
        end
        yield group if block_given?
        group.each do |pin|
          pin.send(:primary_group_index=, pin.id)
          pin.id = "#{group.id}#{pin.id}".to_sym
          pin.send(:primary_group=, group)
          pin.finalize
        end
        if group.size == 1
          Origen.pin_bank.add_pin(group.first, self, options)
        else
          Origen.pin_bank.add_pin_group(group, self, options)
        end
      else
        if power_pin
          pin = PowerPin.new(id || :temp, self, options)
        elsif ground_pin
          pin = GroundPin.new(id || :temp, self, options)
        elsif virtual_pin
          pin = VirtualPin.new(id || :temp, self, options)
        elsif other_pin
          pin = OtherPin.new(id || :temp, self, options)
        else
          pin = Pin.new(id || :temp, self, options)
        end
        yield pin if block_given?
        pin.finalize
        Origen.pin_bank.add_pin(pin, self, options)
      end
    end
    alias_method :add_pins, :add_pin

    def add_power_pin(id = nil, options = {}, &block)
      id, options = nil, id if id.is_a?(Hash)
      options = {
        power_pin: true
      }.merge(options)
      add_pin(id, options, &block)
    end
    alias_method :add_power_pins, :add_power_pin

    def add_ground_pin(id = nil, options = {}, &block)
      id, options = nil, id if id.is_a?(Hash)
      options = {
        ground_pin: true
      }.merge(options)
      add_pin(id, options, &block)
    end
    alias_method :add_ground_pins, :add_ground_pin

    def add_other_pin(id = nil, options = {}, &block)
      id, options = nil, id if id.is_a?(Hash)
      options = {
        other_pin: true
      }.merge(options)
      add_pin(id, options, &block)
    end
    alias_method :add_other_pins, :add_other_pin

    def add_virtual_pin(id = nil, options = {}, &block)
      id, options = nil, id if id.is_a?(Hash)
      options = {
        virtual_pin: true
      }.merge(options)
      add_pin(id, options, &block)
    end
    alias_method :add_virtual_pins, :add_virtual_pin

    # Specify the order that pins will appear in the output pattern, unspecified
    # pins will appear in an arbitrary order at the end
    #
    # API v2, deprecated
    def pin_pattern_order(*pin_ids)
      if pin_ids.last.is_a?(Hash)
        options = pin_ids.pop
      else
        options = {}
      end
      pin_ids.each do |id|
        if pin_aliases[id]
          Origen.app.pin_names[pin_aliases[id].first] = id
          id = pin_aliases[id].first
        end
        Origen.app.pin_pattern_order << id
      end
      Origen.app.pin_pattern_order << options unless options.empty?
    end

    # Specify the pins will not appear in the output pattern
    def pin_pattern_exclude(*pin_ids)
      if pin_ids.last.is_a?(Hash)
        options = pin_ids.pop
      else
        options = {}
      end
      pin_ids.each do |id|
        if pin_aliases[id]
          Origen.app.pin_names[pin_aliases[id].first] = id
          id = pin_aliases[id].first
        end
        Origen.app.pin_pattern_exclude << id
      end
      Origen.app.pin_pattern_exclude << options unless options.empty?
    end

    def add_pin_alias(new_name, original_name, options = {})
      if pin_groups.include?(original_name) # this is a pin group
        if options[:pin] # alias single pin from a pin group
          pin(original_name)[options[:pin]].add_alias(new_name, options)
        else # alias subset of pins from a pin group
          add_pin_group_alias(new_name, original_name, options)
        end
      else # this is a pin
        pin(original_name).add_alias(new_name, options)
      end
    end
    alias_method :pin_alias, :add_pin_alias
    alias_method :alias_pin, :add_pin_alias

    def add_pin_group_alias(new_name, original_name, options = {})
      group = Origen.pin_bank.find_or_create_pin_group(new_name, self, options)
      if options[:pins] # alias to range of pins from a pin group
        options[:pins].each do |mypin|
          pin(new_name).add_pin(pin(original_name)[mypin])
        end
      else
        pin(original_name).each_with_index { |_pin, i| pin(new_name).add_pin(pin(original_name)[i]) }
      end
      group
    end

    # @api private
    #
    # API v2, deprecated
    def pin_aliases
      # Clear this out every time the target changes
      if !(defined? @@pin_aliases_target) ||
         (@@pin_aliases_target != Origen.target.signature)
        Origen::Pins.clear_pin_aliases
        @@pin_aliases_target = Origen.target.signature
      end
      Origen::Pins.pin_aliases
    end

    # API v2, deprecated
    def pin_order
      @pin_order ||= 10_000_000
      @pin_order += 1
    end

    # API v2, deprecated
    def pin_order_block(order)
      pin_order_orig = @pin_order
      @pin_order = order * 1000
      yield
      @pin_order = pin_order_orig
    end

    # Returns true if the module has access to a pin with the given name
    # within the current context
    def has_pin?(id)
      !!Origen.pin_bank.find(id)
    end
    alias_method :has_pins?, :has_pin?

    # Equivalent to the has_pin? method but considers power pins rather than regular pins
    def has_power_pin?(id)
      !!Origen.pin_bank.find(id, power_pin: true)
    end
    alias_method :has_power_pins?, :has_power_pin?

    # Equivalent to the has_pin? method but considers ground pins rather than regular pins
    def has_ground_pin?(id)
      !!Origen.pin_bank.find(id, ground_pin: true)
    end
    alias_method :has_ground_pins?, :has_ground_pin?

    def has_other_pin?(id)
      !!Origen.pin_bank.find(id, other_pin: true)
    end
    alias_method :has_other_pins?, :has_other_pin?

    # Equivalent to the has_pin? method but considers virtual pins rather than regular pins
    def has_virtual_pin?(id)
      !!Origen.pin_bank.find(id, virtual_pin: true)
    end
    alias_method :has_virtual_pins?, :has_virtual_pin?

    def add_pin_group(id, *pins, &_block)
      if pins.last.is_a?(Hash)
        options = pins.pop
      else
        options = {}
      end
      # check if this is a pin group alias
      found = false
      group = nil
      pins_left = pins.dup
      unless options[:pins_only] == true
        pins.each do |i|
          if pin_groups.include?(i)
            group = add_pin_group_alias(id, i, options)
            pins_left.delete(i)
            found = true
          end
        end
      end
      unless pins_left.empty? && !block_given? # not a pin group alias
        group = Origen.pin_bank.find_or_create_pin_group(id, self, options)
        if block_given?
          yield group
        else
          # SMcG:
          #
          # Not 100% sure that this is right, but the idea here is that when manually defining a pin
          # group the user will naturally think in endian order. e.g. when defining a big endian group
          # they would do:
          #
          #   add_pin_group :pa, :pa7, :pa5, :pa1, :pa0
          #
          # But if it was little endian they would probably do:
          #
          #   add_pin_group :pa, :pa0, :pa1, :pa5, :pa7, :endian => :little
          #
          # However I never work on little endian ports so I don't know for sure!
          #
          # In both cases though we always want pins(:pa)[0] to return :pa0.
          if options[:endian] == :little
            pins_left.each { |pin| group.add_pin(pin, options) }
          else
            pins_left.reverse_each { |pin| group.add_pin(pin, options) }
          end
        end
      end
      group = Origen.pin_bank.find_or_create_pin_group(id, self, options) if group.nil?
      group
      # Origen.pin_bank.add_pin_group(group, self, {:pins_exist => true}.merge(options))
    end

    def add_power_pin_group(id, *pins, &block)
      if pins.last.is_a?(Hash)
        options = pins.pop
      else
        options = {}
      end
      options = {
        power_pin: true
      }.merge(options)
      add_pin_group(id, *pins, options, &block)
    end

    def add_ground_pin_group(id, *pins, &block)
      if pins.last.is_a?(Hash)
        options = pins.pop
      else
        options = {}
      end
      options = {
        ground_pin: true
      }.merge(options)
      add_pin_group(id, *pins, options, &block)
    end

    def add_other_pin_group(id, *pins, &block)
      if pins.last.is_a?(Hash)
        options = pins.pop
      else
        options = {}
      end
      options = {
        other_pin: true
      }.merge(options)
      add_pin_group(id, *pins, options, &block)
    end

    def add_virtual_pin_group(id, *pins, &block)
      if pins.last.is_a?(Hash)
        options = pins.pop
      else
        options = {}
      end
      options = {
        virtual_pin: true
      }.merge(options)
      add_pin_group(id, *pins, options, &block)
    end

    # Similar to the pins method except that this method will bypass the package/mode/configuration
    # scope.
    #
    # Therefore with no id supplied it will return all known pins and with an id it will return the
    # given pin object regardless of where or not it is enabled by the current context
    def all_pins(id = nil, _options = {}, &_block)
      if id
        pin = Origen.pin_bank.find(id, ignore_context: true)
      else
        Origen.pin_bank.all_pins
      end
    end

    # Equivalent to the all_pins method but considers power pins rather than regular pins
    def all_power_pins(id = nil, _options = {}, &_block)
      if id
        pin = Origen.pin_bank.find(id, ignore_context: true, power_pin: true)
      else
        Origen.pin_bank.all_power_pins
      end
    end

    # Equivalent to the all_pins method but considers ground pins rather than regular pins
    def all_ground_pins(id = nil, _options = {}, &_block)
      if id
        pin = Origen.pin_bank.find(id, ignore_context: true, ground_pin: true)
      else
        Origen.pin_bank.all_ground_pins
      end
    end

    # Equivalent to the all_pins method but considers other pins rather than regular pins
    def all_other_pins(id = nil, _options = {}, &_block)
      if id
        pin = Origen.pin_bank.find(id, ignore_context: true, other_pin: true)
      else
        Origen.pin_bank.all_other_pins
      end
    end

    # Equivalent to the all_pins method but considers ground pins rather than regular pins
    def all_virtual_pins(id = nil, _options = {}, &_block)
      if id
        pin = Origen.pin_bank.find(id, ignore_context: true, virtual_pin: true)
      else
        Origen.pin_bank.all_virtual_pins
      end
    end

    def pin_groups(id = nil, options = {}, &_block)
      id, options = nil, id if id.is_a?(Hash)
      if id
        pin = Origen.pin_bank.find(id, options)
        unless pin
          puts <<-END
You have tried to reference pin_group :#{id} within #{self.class} but it does not exist, this could be
because the pin has not been defined yet or it is an alias that is not available in the current context.

If you meant to define the pin_group then use the add_pin_group method instead.

          END
          fail 'Pin not found'
        end
        pin
      else
        Origen.pin_bank.pin_groups(options)
      end
    end
    alias_method :pin_group, :pin_groups

    # Equivalent to the pin_groups method but considers power pins rather than regular pins
    def power_pin_groups(id = nil, options = {}, &_block)
      id, options = nil, id if id.is_a?(Hash)
      if id
        pin = Origen.pin_bank.find(id, options.merge(power_pin: true))
        unless pin
          puts <<-END
You have tried to reference power_pin_group :#{id} within #{self.class} but it does not exist, this could be
because the pin group has not been defined yet or it is an alias that is not available in the current context.

If you meant to define the power_pin_group then use the add_power_pin_group method instead.

          END
          fail 'Power pin group not found'
        end
        pin
      else
        Origen.pin_bank.power_pin_groups(options)
      end
    end
    alias_method :power_pin_group, :power_pin_groups

    # Equivalent to the pin_groups method but considers ground pins rather than regular pins
    def ground_pin_groups(id = nil, options = {}, &_block)
      id, options = nil, id if id.is_a?(Hash)
      if id
        pin = Origen.pin_bank.find(id, options.merge(ground_pin: true))
        unless pin
          puts <<-END
You have tried to reference ground_pin_group :#{id} within #{self.class} but it does not exist, this could be
because the pin group has not been defined yet or it is an alias that is not available in the current context.

If you meant to define the ground_pin_group then use the add_ground_pin_group method instead.

          END
          fail 'Power pin group not found'
        end
        pin
      else
        Origen.pin_bank.ground_pin_groups(options)
      end
    end
    alias_method :ground_pin_group, :ground_pin_groups

    # Equivalent to the pin_groups method but considers other pins rather than regular pins
    def other_pin_groups(id = nil, options = {}, &_block)
      id, options = nil, id if id.is_a?(Hash)
      if id
        pin = Origen.pin_bank.find(id, options.merge(other_pin: true))
        unless pin
          puts <<-END
    You have tried to reference other_pin_group :#{id} within #{self.class} but it does not exist, this could be
    because the pin group has not been defined yet or it is an alias that is not available in the current context.

    If you meant to define the other_pin_group then use the add_other_pin_group method instead.

          END
          fail 'Other pin group not found'
        end
        pin
      else
        Origen.pin_bank.other_pin_groups(options)
      end
    end
    alias_method :other_pin_group, :other_pin_groups

    # Equivalent to the pin_groups method but considers virtual pins rather than regular pins
    def virtual_pin_groups(id = nil, options = {}, &_block)
      id, options = nil, id if id.is_a?(Hash)
      if id
        pin = Origen.pin_bank.find(id, options.merge(virtual_pin: true))
        unless pin
          puts <<-END
You have tried to reference virtual_pin_group :#{id} within #{self.class} but it does not exist, this could be
because the pin group has not been defined yet or it is an alias that is not available in the current context.

If you meant to define the virtual_pin_group then use the add_virtual_pin_group method instead.

          END
          fail 'Utility pin group not found'
        end
        pin
      else
        Origen.pin_bank.virtual_pin_groups(options)
      end
    end
    alias_method :virtual_pin_group, :virtual_pin_groups

    # Permits access via object.pin(x), returns a hash of all pins if no id
    # is specified.
    # ==== Examples
    #   $top.pin(:done)
    #   $soc.pin(:port_a1)
    #   pin(:fail)          # Access directly from within the module
    def pins(id = nil, options = {}, &_block)
      id, options = nil, id if id.is_a?(Hash)
      if id
        pin = Origen.pin_bank.find(id, options)
        unless pin
          puts <<-END
You have tried to reference pin :#{id} within #{self.class} but it does not exist, this could be
because the pin has not been defined yet or it is an alias that is not available in the current context.

If you meant to define the pin then use the add_pin method instead.

          END
          fail 'Pin not found'
        end
        pin
      else
        if options[:power_pin]
          Origen.pin_bank.power_pins
        elsif options[:ground_pin]
          Origen.pin_bank.ground_pins
        elsif options[:virtual_pin]
          Origen.pin_bank.virtual_pins
        elsif options[:other_pin]
          Origen.pin_bank.other_pins
        else
          Origen.pin_bank.pins
        end
      end
    end
    alias_method :pin, :pins

    # Equivalent to the pins method but considers power pins rather than regular pins
    def power_pins(id = nil, options = {}, &block)
      id, options = nil, id if id.is_a?(Hash)
      options = {
        power_pin: true
      }.merge(options)
      pins(id, options, &block)
    end
    alias_method :power_pin, :power_pins

    # Equivalent to the pins method but considers ground pins rather than regular pins
    def ground_pins(id = nil, options = {}, &block)
      id, options = nil, id if id.is_a?(Hash)
      options = {
        ground_pin: true
      }.merge(options)
      pins(id, options, &block)
    end
    alias_method :ground_pin, :ground_pins

    # Equivalent to the pins method but considers other pins rather than regular pins
    def other_pins(id = nil, options = {}, &block)
      id, options = nil, id if id.is_a?(Hash)
      options = {
        other_pin: true
      }.merge(options)
      pins(id, options, &block)
    end
    alias_method :other_pin, :other_pins

    # Equivalent to the pins method but considers virtual pins rather than regular pins
    def virtual_pins(id = nil, options = {}, &block)
      id, options = nil, id if id.is_a?(Hash)
      options = {
        virtual_pin: true
      }.merge(options)
      pins(id, options, &block)
    end
    alias_method :virtual_pin, :virtual_pins

    def delete_all_pins
      Origen.pin_bank.send :empty!
    end

    # Delete any pin or pin group.  If arg is a pin then delete the pin and any instances
    # of it in any pin groups
    def delete_pin(id, options = {})
      id = id.to_sym
      # Check if this is a Pin or a PinGroup
      if pin_groups.key? id
        Origen.pin_bank.delete_pingroup(Origen.pin_bank.find_pin_group(id, options))
      elsif pins(id).class.to_s.match(/Pin/)
        Origen.pin_bank.delete_pin(Origen.pin_bank.find(id, options))
      else
        fail "Error: the object #{id} you tried to delete is not a pin or pingroup"
      end
    end
  end
end
