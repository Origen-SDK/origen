module Origen
  module Pins
    class Pin
      include PinCommon

      # Any attributes listed here will be looked up for the current function defined
      # by the current mode and configuration context before falling back to a default
      FUNCTION_SCOPED_ATTRIBUTES = [:name, :direction, :option, :group, :ip_block, :meta]

      # Any attributes listed here will be looked up for the current package context
      # before falling back to a default
      PACKAGE_SCOPED_ATTRIBUTES = [:location, :dib_assignment, :dib_meta]

      # Pin Types
      TYPES = [:analog, :digital]

      attr_accessor :order
      # Inverts pin states for drive and compare, can be useful if a timing set change requires clocks to drive low for example when all pattern logic has been set up to drive them high.
      attr_accessor :invert
      # Attribute used to generate vectors where the pin state is assigned the
      # repeat_previous opcode, used by Tester#repeat_previous
      attr_accessor :repeat_previous
      attr_reader :owner
      attr_reader :size
      # Returns a hash containing the aliases associated with the given pin
      attr_reader :aliases
      # Returns a hash containing the functions associated with the given pin
      attr_reader :functions
      # Internal power supply pin is connected to
      attr_accessor :supply
      attr_accessor :supply_str
      # Boolean on whether pin is open drain
      attr_accessor :open_drain
      # Boolean on whether pin has external pull-up
      attr_accessor :ext_pullup
      # Boolean on whether pin has external pull-down
      attr_accessor :ext_pulldown
      # Pin type, either :analog or :digital
      attr_accessor :type
      # Pin RTL name, short term solution for products that do not get full HDL path for pins
      attr_accessor :rtl_name

      attr_accessor :description
      attr_accessor :notes

      # Should be instantiated through the HasPins macros
      def initialize(id, owner, options = {}) # :nodoc:
        options = {
          reset:        :dont_care,
          invert:       false,
          direction:    :io,
          open_drain:   false,
          ext_pullup:   false,
          ext_pulldown: false,
          rtl_name:     nil
        }.merge(options)
        @aliases = {}
        @functions = {}
        @direction = sanitize_direction(options[:direction])
        @invert = options[:invert]
        @reset = options[:reset]
        @id = id
        @name = options[:name]
        @rtl_name = options[:rtl_name]
        @suspend = false
        @order = options[:order]
        @supply = options[:supply]
        @open_drain = options[:open_drain]
        @ext_pullup = options[:ext_pullup]
        @ext_pulldown = options[:ext_pulldown]
        @type = options[:type]
        @dib_assignment = [] # Array to handle multi-site testing
        @size = 1
        @value = 0
        @clock = nil
        @meta = options[:meta] || {}
        @dib_meta = options[:dib_meta] || {}
        on_init(owner, options)
        # Assign the initial state from the method so that any inversion is picked up...
        send(@reset)
      end

      # Returns the drive cycle wave assigned to the pin based on the currently enabled timeset,
      # or nil if none is set.
      # Note that if a timeset is set then all pins will always return a wave as they will pick
      # up a default waveform if none is explicitly assigned to it.
      def drive_wave(code = nil)
        if t = dut.current_timeset
          # Cache this for performance since potentially this is something that could be called on
          # every cycle in some applications
          @drive_waves ||= {}
          @drive_waves[t.id] ||= {}
          @drive_waves[t.id][code] ||= dut.current_timeset.send(:wave_for, self, type: :drive, code: code)
        end
      end

      # Returns the compare cycle wave assigned to the pin based on the currently enabled timeset,
      # or nil if none is set
      # Note that if a timeset is set then all pins will always return a wave as they will pick
      # up a default waveform if none is explicitly assigned to it.
      def compare_wave(code = nil)
        if t = dut.current_timeset
          # Cache this for performance since potentially this is something that could be called on
          # every cycle in some applications
          @compare_waves ||= {}
          @compare_waves[t.id] ||= {}
          @compare_waves[t.id][code] ||= dut.current_timeset.send(:wave_for, self, type: :compare, code: code)
        end
      end

      # Causes the pin to continuously drive 1 for 2 seconds and then drive 0 for 2 seconds.
      #
      # This is not an API that is intended to be used within a pattern. Rather it is a debug aid when
      # setting up something like a bench test environment that uses Origen Link. For example you would
      # call this method on a pin from a console session, then confirm with a multimeter that the pin
      # is toggling on the relevant hardware.
      #
      # Call Pin#goodbye to stop it.
      #
      # @example Call from an origen console like this
      #
      #   dut.pin(:tdi).hello
      def hello
        drive_hi
        @@hello_pins ||= []
        @@hello_pins << self unless @@hello_pins.include?(self)
        @@hello_loop ||= Thread.new do
          loop do
            @@hello_pins.each(&:toggle)
            if $tester
              # Add a dummy timeset if one is not set yet, doesn't really matter what it is in this case
              # and better not to force the user to setup a debug workaround due to running outside of a pattern
              $tester.set_timeset('hello_world', 40) unless $tester.timeset
              $tester.cycle
            end
            sleep 2
          end
        end
        puts "Pin #{name} is toggling with a period of 2 seconds"
      end

      # See Pin#hello
      def goodbye
        @@hello_pins.delete(self)
        puts "Pin #{name} has stopped toggling"
      end

      # When sorting pins do it by ID
      def <=>(other_pin)
        @id <=> other_pin.id
      end

      def name=(val)
        @name = val
      end

      def functions=(val)
        if val.is_a? Hash
          val.each do |name, _whatever|
            add_function name
          end
        else
          fail "Attempt to set the functions hash on pin #{@name}.  Argument must be a Hash."
        end
      end

      # This generates getter methods that will lookup the given attribute within the
      # scope of the current package and falling back to a default if defined
      PACKAGE_SCOPED_ATTRIBUTES.each do |attribute|
        define_method attribute do |options = {}|
          default = instance_variable_get("@#{attribute}")
          package_id = options[:package] || current_package_id
          package_id = package_id.to_sym if package_id
          if packages[package_id]
            packages[package_id][attribute] || default
          elsif packages[:all]
            packages[:all][attribute] || default
          else
            default
          end
        end
      end

      # This generates getter methods that will lookup the given attribute within the
      # scope of the function enabled by the current mode and configuration attributes
      # and falling back to a default if defined
      FUNCTION_SCOPED_ATTRIBUTES.each do |attribute|
        define_method attribute do |options = {}|
          default = instance_variable_get("@#{attribute}")
          if options[:function]
            v = functions[:ids][options[:function]][attribute]
            if v
              if v.is_a?(Hash) && default.is_a?(Hash)
                return default.merge(v) # v will overwrite any default values
              else
                return v
              end
            end
            # else fall back to context-based lookup
          end
          mode_id = options[:mode] || current_mode_id
          mode_id = mode_id.to_sym if mode_id
          mode = functions[mode_id] || functions[:all]
          if mode
            config_id = options[:configuration] || options[:config] || current_configuration
            config_id = config_id.to_sym if config_id
            configuration = mode[config_id] || mode[:all]
            if configuration
              v = configuration[attribute]
              if v
                if v.is_a?(Hash) && default.is_a?(Hash)
                  return default.merge(v) # v will overwrite any default values
                else
                  return v
                end
              else
                default
              end
            else
              default
            end
          else
            default
          end
        end
      end

      alias_method :function_scoped_name, :name

      # Returns the name of the pin, if a name has been specifically assigned by the application
      # (via name=) then this will be returned, otherwise the name of the current function if present
      # will be returned, and then as a last resort the ID of the pin
      def name(options = {})
        # Return a specifically assigned name in preference to a function name
        (options.empty? ? @name : nil) || function_scoped_name(options) || @id
      end

      # Returns the value held by the pin as a string formatted to the current tester's pattern syntax
      #
      # @example
      #
      #   pin.drive_hi
      #   pin.to_vector   # => "1"
      #   pin.expect_lo
      #   pin.to_vector   # => "L"
      def to_vector
        @vector_formatted_value ||= Origen.tester.format_pin_state(self)
      end

      # @api private
      def invalidate_vector_cache
        @vector_formatted_value = nil
        groups.each { |_name, group| group.invalidate_vector_cache }
      end

      # Set the pin value and state from a string formatted to the current tester's pattern syntax,
      # this is the opposite of the to_vector method
      #
      # @example
      #
      #   pin.vector_formatted_value = "L"
      #   pin.driving?                      # => false
      #   pin.value                         # => 0
      #   pin.vector_formatted_value = "1"
      #   pin.driving?                      # => true
      #   pin.value                         # => 1
      def vector_formatted_value=(val)
        unless @vector_formatted_value == val
          Origen.tester.update_pin_from_formatted_state(self, val)
          @vector_formatted_value = val
        end
      end

      def inspect
        "<#{self.class}:#{object_id}>"
      end

      def describe(options = {})
        desc = ['********************']
        desc << "Pin id: #{id}"
        func_aliases = []
        unless functions.empty?
          desc << ''
          desc << 'Functions'
          desc << '---------'
          functions.each do |mode, configurations|
            unless mode == :ids
              configurations.each do |configuration, attrs|
                a = ":#{attrs[:name]}".ljust(30)
                func_aliases << attrs[:name]
                unless mode == :all
                  a += ":modes => [#{[mode].flatten.map { |id| ':' + id.to_s }.join(', ')}]"
                  prev = true
                end
                unless configuration == :all
                  a += ' ; ' if prev
                  a += ":configurations => [#{[configuration].flatten.map { |id| ':' + id.to_s }.join(', ')}]"
                end
                desc << a
              end
            end
          end
        end
        unless aliases.empty?
          desc << ''
          desc << 'Aliases'
          desc << '-------'
          aliases.each do |name, context|
            unless func_aliases.include?(name)
              a = ":#{name}".ljust(30)
              unless context[:packages].empty? || context[:packages] == [:all]
                a += ":packages => [#{context[:packages].map { |id| ':' + id.to_s }.join(', ')}]"
                prev = true
              end
              unless context[:modes].empty? || context[:modes] == [:all]
                a += ' ; ' if prev
                a += ":modes => [#{context[:modes].map { |id| ':' + id.to_s }.join(', ')}]"
                prev = true
              end
              unless context[:configurations].empty? || context[:configurations] == [:all]
                a += ' ; ' if prev
                a += ":configurations => [#{context[:configurations].map { |id| ':' + id.to_s }.join(', ')}]"
              end
              desc << a
            end
          end
        end
        unless Origen.top_level.modes.empty?
          desc << ''
          desc << 'Modes'
          desc << '-------'
          Origen.top_level.modes.each do |name|
            unless option(mode: name).nil?
              a = ":#{name}".ljust(30) + ":mode => #{option(mode: name)}"
              desc << a
            end
          end
        end
        unless groups.empty?
          desc << ''
          desc << 'Groups'
          desc << '------'
          desc << groups.map { |name, _group| ':' + name.to_s }.join(', ')
        end
        desc << '********************'
        if options[:return]
          desc
        else
          puts desc.join("\n")
        end
      end

      # If the pin was defined initially as part of a group then this will return that group,
      # otherwise it will return nil
      def group
        @primary_group
      end
      alias_method :primary_group, :group

      # If the pin is a member of a primary group, this returns its index number within that
      # group, otherwise returns nil
      def group_index
        @primary_group_index
      end
      alias_method :primary_group_index, :group_index

      # Returns a hash containing the pin groups that the given pin is a member of
      def groups
        # Origen.pin_bank.all_pin_groups.select do |name, group|
        @groups ||= Origen.pin_bank.pin_groups.select do |_name, group|
          group.include?(self)
        end
      end
      alias_method :pin_groups, :groups

      def invalidate_group_cache
        @groups = nil
      end

      # Add a location identifier to the pin, this is a free format field which can be a
      # pin number or BGA co-ordinate for example.
      #
      # @example Adding a location by package
      #   $dut.pin(:pin3).add_location "B3", :package => :p1
      #   $dut.pin(:pin3).add_location "B2", :package => :p2
      def add_location(str, options = {})
        packages = resolve_packages(options)
        if packages.empty?
          @location = str
          add_alias str.to_s.symbolize, package: :all, mode: :all, configuration: :all
        else
          packages.each do |package_id|
            package_id = package_id.respond_to?(:id) ? package_id.id : package_id
            self.packages[package_id] ||= {}
            self.packages[package_id][:location] = str
            add_alias str.to_s.symbolize, package: package_id, mode: :all, configuration: :all
          end
        end
      end
      alias_method :add_locn, :add_location

      # Add a Device Interface Board (e.g. probecard at wafer probe or loadboard at final package test)
      # assignment to the pin.  Some refer to this as a channel but API name is meant to be generic.
      def add_dib_assignment(str, options = {})
        options = {
          site: 0
        }.merge(options)
        packages = resolve_packages(options)
        if packages.empty?
          @dib_assignment[options[:site]] = str
          add_alias str.to_s.symbolize, package: :all, mode: :all, configuration: :all
        else
          packages.each do |package_id|
            package_id = package_id.respond_to?(:id) ? package_id.id : package_id
            self.packages[package_id] ||= {}
            self.packages[package_id][:dib_assignment] ||= []
            self.packages[package_id][:dib_assignment][options[:site]] = str
            add_alias str.to_s.symbolize, package: package_id, mode: :all, configuration: :all
          end
        end
      end
      alias_method :add_dib_info, :add_dib_assignment
      alias_method :add_channel, :add_dib_assignment

      def add_dib_meta(pkg, options)
        unless Origen.top_level.packages.include? pkg
          Origen.log.error("Cannot add DIB metadata for package '#{pkg}', that package has not been added yet!")
          fail
        end
        options.each do |attr, attr_value|
          packages[pkg][:dib_meta] ||= {}
          packages[pkg][:dib_meta][attr] = attr_value
          add_alias attr_value.to_s.symbolize, package: pkg, mode: :all, configuration: :all
        end
      end

      # Returns the number of test sites enabled for the pin
      def sites
        dib_assignment.size
      end

      def sanitize_direction(val)
        if val
          val = val.to_s.downcase.gsub(/\//, '')
          if val =~ /i.*o/
            :io
          elsif val =~ /^i/
            :input
          elsif val =~ /^o/
            :output
          else
            fail "Unknown pin direction: #{val}"
          end
        end
      end

      # Sets the default direction of the pin, :input, :output or :io (default). If a function specific
      # direction has been specified that will override this value.
      def direction=(val)
        @direction = sanitize_direction(val)
      end

      # Add a function to the pin.
      #
      # @example Adding a mode-specific function
      #   pin.add_function :tdi, :direction => :input
      #   pin.add_function :nvm_fail, :mode => :nvmbist, :direction => :output
      def add_function(id, options = {})
        id = id.to_sym
        add_function_attributes(options.merge(name: id, id: id.to_sym))
        f = FunctionProxy.new(id, self)
        add_alias id, packages: :all, obj: f
      end

      def add_function_attributes(options = {})
        id = options.delete(:id)
        modes = resolve_modes(options)
        configurations = resolve_configurations(options)
        options[:direction] = sanitize_direction(options[:direction]) if options[:direction]
        if modes.empty?
          modes = [:all]
        end
        if configurations.empty?
          configurations = [:all]
        end
        # Supports newer attribute lookup by function ID
        if id
          functions[:ids] ||= {}
          if functions[:ids][id]
            functions[:ids][id] = functions[:ids][id].merge!(options)
          else
            functions[:ids][id] = options.dup
          end
        end
        # Supports older attribute lookup by mode context
        modes.each do |mode|
          configurations.each do |configuration|
            functions[mode.to_sym] ||= {}
            if functions[mode.to_sym][configuration.to_sym]
              functions[mode.to_sym][configuration.to_sym] = functions[mode.to_sym][configuration.to_sym].merge!(options)
            else
              functions[mode.to_sym][configuration.to_sym] = options
            end
          end
        end
      end

      # Add an alias to the given pin.
      #
      # If the options contain a package, mode or configuration reference then the alias
      # will only work under that context.
      def add_alias(id, options = {})
        obj = options.delete(:obj) || self
        if aliases[id]
          aliases[id][:packages] += resolve_packages(options)
          aliases[id][:modes] += resolve_modes(options)
          aliases[id][:configurations] += resolve_configurations(options)
          aliases[id][:packages].uniq!
          aliases[id][:modes].uniq!
          aliases[id][:configurations].uniq!
        else
          aliases[id] = {
            packages:       resolve_packages(options),
            modes:          resolve_modes(options),
            configurations: resolve_configurations(options)
          }
          Origen.pin_bank.register_alias(id, obj, options)
        end
      end

      # Returns true if the pin has the given alias within the given or current context
      def has_alias?(id, options = {})
        if aliases[id]
          if options[:ignore_context]
            true
          else
            packages = resolve_packages(options)
            modes = resolve_modes(options)
            configurations = resolve_configurations(options)
            begin
              aliases[id][:packages].include?(:all) || aliases[id][:packages].empty? ||
                packages.any? { |package| aliases[id][:packages].include?(package) }
            end && begin
              aliases[id][:modes].include?(:all) || aliases[id][:modes].empty? ||
                modes.any? { |mode| aliases[id][:modes].include?(mode) }
            end && begin
              aliases[id][:configurations].include?(:all) || aliases[id][:configurations].empty? ||
                configurations.any? { |config| aliases[id][:configurations].include?(config) }
            end
          end
        else
          false
        end
      end

      # Returns true if the pin is an alias of the given pin name
      def is_alias_of?(name)
        if Origen.pin_bank.find(name)
          Origen.pin_bank.find(name).id == Origen.pin_bank.find(self).id
        else
          false
        end
      end

      # Returns true if the pin belongs to a pin group.
      #
      #   add_pins :jtag, size: 6
      #   add_pin  :done
      #   add_pin_alias :fail, :jtag, pin: 4
      #
      #   pin(:done).belongs_to_a_pin_group?  # => false
      #   pin(:fail).belongs_to_a_pin_group?  # => true
      def belongs_to_a_pin_group?
        !groups.empty?
      end

      def value
        @value
      end
      alias_method :data, :value

      def suspend
        invalidate_vector_cache
        @suspend = true
      end

      def suspended?
        @suspend
      end

      # Will resume compares on this pin
      def resume
        invalidate_vector_cache
        @suspend = false
      end

      def repeat_previous=(bool)
        invalidate_vector_cache
        @repeat_previous = bool
      end

      def repeat_previous?
        @repeat_previous
      end

      def set_state(state)
        invalidate_vector_cache
        @repeat_previous = false
        @state = state
      end

      def set_value(val)
        invalidate_vector_cache
        if val.is_a?(String) || val.is_a?(Symbol)
          @vector_formatted_value = val.to_s
        else
          # If val is a data bit extract the value of it
          val = val.respond_to?(:data) ? val.data : val
          # Assume driving/asserting a nil value means 0
          val = 0 unless val
          if val > 1
            fail "Attempt to set a value of #{val} on pin #{name}"
          end
          @repeat_previous = false
          if inverted?
            @value = val == 0 ? 1 : 0
          else
            @value = val
          end
        end
      end
      alias_method :data=, :set_value

      def cycle # :nodoc:
        Origen.tester.cycle
      end

      def state
        @state
      end

      def state=(value)
        invalidate_vector_cache
        @state = value
      end

      # Set the pin to drive a 1 on future cycles
      def drive_hi
        set_state(:drive)
        set_value(1)
      end

      def drive_hi!
        drive_hi
        cycle
      end

      # Set the pin to drive a high voltage on future cycles (if the tester supports it).
      # For example on a J750 high-voltage channel the pin state would be set to "2"
      def drive_very_hi
        set_state(:drive_very_hi)
        set_value(1)
      end

      def drive_very_hi!
        drive_very_hi
        cycle
      end

      # Set the pin to drive a 0 on future cycles
      def drive_lo
        set_state(:drive)
        set_value(0)
      end

      def drive_lo!
        drive_lo
        cycle
      end

      def drive_mem
        set_state(:drive_mem)
      end

      def drive_mem!
        drive_mem
        cycle
      end

      def expect_mem
        set_state(:expect_mem)
      end

      def expect_mem!
        expect_mem
        cycle
      end

      # Set the pin to expect a 1 on future cycles
      def assert_hi(_options = {})
        set_state(:compare)
        set_value(1)
      end
      alias_method :expect_hi, :assert_hi
      alias_method :compare_hi, :assert_hi

      def assert_hi!
        assert_hi
        cycle
      end
      alias_method :expect_hi!, :assert_hi!
      alias_method :compare_hi!, :assert_hi!

      # Set the pin to expect a 0 on future cycles
      def assert_lo(_options = {})
        set_state(:compare)
        set_value(0)
        # Planning to add the active load logic to the tester instead...
        # options = { :active => false    #if active true means to take tester active load capability into account
        #          }.merge(options)
        # unless state_to_be_inverted?
        #  self.state = ($tester.active_loads || !options[:active]) ? $tester.pin_state(:expect_lo) : $tester.pin_state(:dont_care)
        # else
        #  self.state = ($tester.active_loads || !options[:active]) ? $tester.pin_state(:expect_hi) : $tester.pin_state(:dont_care)
        # end
      end
      alias_method :expect_lo, :assert_lo
      alias_method :compare_lo, :assert_lo

      def assert_lo!
        assert_lo
        cycle
      end
      alias_method :expect_lo!, :assert_lo!
      alias_method :compare_lo!, :assert_lo!

      # Set the pin to X on future cycles
      def dont_care
        set_state(:dont_care)
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
        set_state(:drive)
        set_value(value)
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
        set_state(:compare)
        set_value(value)
      end
      alias_method :compare, :assert
      alias_method :expect, :assert

      def assert!(*args)
        assert(*args)
        cycle
      end
      alias_method :compare!, :assert!
      alias_method :expect!, :assert!

      def assert_midband
        set_state(:compare_midband)
      end
      alias_method :compare_midband, :assert_midband
      alias_method :expect_midband, :assert_midband

      def assert_midband!
        assert_midband
        cycle
      end
      alias_method :compare_midband!, :assert_midband!
      alias_method :expect_midband!, :assert_midband!

      # Returns the state of invert
      def inverted?
        @invert
      end

      # Returns true if the pin is currently in a compare state
      def comparing?
        !@suspend &&
          state == :compare
      end

      # Returns true if the pin is currently in a compare mem state
      def comparing_mem?
        !@suspend &&
          state == :expect_mem
      end

      # Returns true if the pin is currently in a compare state
      def comparing_midband?
        !@suspend &&
          state == :compare_midband
      end

      # Returns true if the pin is currently in a drive state
      def driving?
        !@suspend &&
          (state == :drive || state == :drive_very_hi)
      end

      # Returns true if the pin is currently in a drive mem state
      def driving_mem?
        !@suspend &&
          state == :drive_mem
      end

      # Returns true if pin is in high voltage state
      def high_voltage?
        !@suspend &&
          state == :drive_very_hi
      end

      def toggle
        unless state == :dont_care
          set_value(value == 0 ? 1 : 0)
        end
      end

      def toggle!
        toggle
        cycle
      end

      # Mark the (data) from the pin to be captured
      def capture
        set_state(:capture)
      end
      alias_method :store, :capture

      # Mark the (data) from the pin to be captured and trigger a cycle
      def capture!
        capture
        cycle
      end
      alias_method :store!, :capture!

      # Returns true if the (data) from the pin is marked to be captured
      def to_be_captured?
        state == :capture
      end
      alias_method :to_be_stored?, :to_be_captured?
      alias_method :is_to_be_stored?, :to_be_captured?
      alias_method :is_to_be_captured?, :to_be_captured?

      # Restores the state of the pin at the end of the given block
      # to the state it was in at the start of the block
      #
      #   pin(:invoke).driving?  # => true
      #   pin(:invoke).restore_state do
      #     pin(:invoke).dont_care
      #     pin(:invoke).driving?  # => false
      #   end
      #   pin(:invoke).driving?  # => true
      def restore_state
        save
        yield
        restore
      end

      def save # :nodoc:
        @_saved_state = @state
        @_saved_value = @value
        @_saved_suspend = @suspend
        @_saved_invert = @invert
        @_saved_repeat_previous = @repeat_previous
      end

      def restore # :nodoc:
        invalidate_vector_cache
        @state = @_saved_state
        @value = @_saved_value
        @suspend = @_saved_suspend
        @invert = @_saved_invert
        @repeat_previous = @_saved_repeat_previous
      end

      def is_not_a_clock?
        @clock.nil?
      end

      def is_a_clock?
        !(@clock.nil?)
      end

      def is_a_running_clock?
        @clock.running?
      end

      def enable_clock(options = {})
        @clock = PinClock.new(self, options)
      end

      def disable_clock(options = {})
        @clock.stop_clock(options)
        @clock = nil
      end

      def update_clock
        @clock.update_clock
      end

      def start_clock(options = {})
        enable_clock(options) if self.is_not_a_clock?
        @clock.start_clock(options)
      end
      alias_method :resume_clock, :start_clock

      def stop_clock(options = {})
        @clock.stop_clock(options)
      end
      alias_method :pause_clock, :stop_clock

      def next_edge
        @clock.next_edge
      end

      def duty_cycles
        @clock.cycles_per_duty
      end

      def half_period
        @clock.cycles_per_half_period
      end

      def toggle_clock
        fail "ERROR: Clock on #{@owner.name} not running." unless is_a_running_clock?
        @clock.toggle
      end

      # Delete this pin (self).  Used bang in method name to keep same for pins and
      # pin collections.  Pin collections already had a delete method which deletes
      # a pin from the collection.  Needed delete! to indicate it is deleting the
      # actual pin or pin group calling the method.
      def delete!
        owner.delete_pin(self)
      end

      def type=(value)
        if TYPES.include? value
          @type = value
        else
          fail "Pin type '#{value}' must be set to one of the following: #{TYPES.join(', ')}"
        end
      end

      def open_drain=(value)
        if [true, false].include? value
          @open_drain = value
        else
          fail "Pin open_drain  attribute '#{value}' must be either true or false"
        end
      end

      def ext_pullup=(value)
        if [true, false].include? value
          @ext_pullup = value
        else
          fail "Pin ext_pullup  attribute '#{value}' must be either true or false"
        end
      end

      def ext_pulldown=(value)
        if [true, false].include? value
          @ext_pulldown = value
        else
          fail "Pin ext_pulldown  attribute '#{value}' must be either true or false"
        end
      end

      def method_missing(m, *args, &block)
        if meta.include? m
          meta[m]
        else
          super
        end
      end

      def respond_to_missing?(m, include_private = false)
        meta[m] || super
      end

      private

      def primary_group=(group)
        @primary_group = group
      end

      def primary_group_index=(number)
        @primary_group_index = number
      end
    end
  end
end
