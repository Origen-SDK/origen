module Origen
  module Pins
    # Stores all pins, pin aliases and pin groups for the current target.
    # A central store is used to allow either top-level or sub-block objects to
    # add pins to the current context available to the testers.
    #
    # The global Origen pin bank (an instance of this class) is returned from Origen.pin_bank.
    class PinBank
      include Origen::CoreCallbacks

      # There is one pin bank per Origen thread, this clears the bank every time the target is changed
      #
      # @api private
      def before_load_target
        empty!
      end

      # Add the given pin to the bank
      #
      # @return [Origen::Pins::Pin] the supplied pin object
      def add_pin(pin, _owner, _options = {})
        if pin.is_a?(PowerPin)
          bank = all_power_pins
        elsif pin.is_a?(GroundPin)
          bank = all_ground_pins
        else
          bank = all_pins
        end
        if bank[pin.id]
          fail "A pin with id #{pin.id} already exists!"
        end
        all_ids << pin.id
        bank[pin.id] = pin
        # If ends in a number
        # if !options[:dont_create_group] && pin.id.to_s =~ /(.*?)(\d+)$/
        #  # Create a new group if one with the given name doesn't already exist
        #  unless group = all_pin_groups[$1.to_sym]
        #    group = PinCollection.new(owner, options)
        #    group.id = $1.to_sym
        #    all_pin_groups[$1.to_sym] = group
        #  end
        #  group.add_pin(pin)
        # end
        pin
      end

      def add_pin_group(group, owner, options = {})
        unless options[:pins_exist]
          group.each do |pin|
            add_pin(pin, owner, options.merge(dont_create_group: true))
          end
        end
        store_pin_group(group, options)
        group
      end

      # Returns a hash containing all pins available in the current context stored by their primary ID
      def pins(options = {})
        all_pins.select do |_id, pin|
          pin.enabled?(options)
        end
      end

      def power_pins(options = {})
        all_power_pins.select do |_id, pin|
          pin.enabled?(options)
        end
      end

      def ground_pins(options = {})
        all_ground_pins.select do |_id, pin|
          pin.enabled?(options)
        end
      end

      # Returns a hash containing all pin_groups available in the current context stored by their primary ID
      def pin_groups(options = {})
        current_pin_group_store(all_pin_groups, options).select do |_id, group|
          group.enabled?(options)
        end
      end

      # Returns a hash containing all power_pin_groups available in the current context stored by their primary ID
      def power_pin_groups(options = {})
        current_pin_group_store(all_power_pin_groups, options).select do |_id, group|
          group.enabled?(options)
        end
      end

      # Returns a hash containing all ground_pin_groups available in the current context stored by their primary ID
      def ground_pin_groups(options = {})
        current_pin_group_store(all_ground_pin_groups, options).select do |_id, group|
          group.enabled?(options)
        end
      end

      # Returns a hash containing all pins stored by their primary ID
      def all_pins
        @all_pins ||= {}
      end

      # Returns a hash containing all pin groups stored by context
      def all_pin_groups
        @all_pin_groups ||= {}
      end

      # Returns a hash containing all power pins stored by their primary ID
      def all_power_pins
        @all_power_pins ||= {}
      end

      # Returns a hash containing all ground pins stored by their primary ID
      def all_ground_pins
        @all_ground_pins ||= {}
      end

      # Returns a hash containing all power pin groups stored by context
      def all_power_pin_groups
        @all_power_pin_groups ||= {}
      end

      # Returns a hash containing all ground pin groups stored by context
      def all_ground_pin_groups
        @all_ground_pin_groups ||= {}
      end

      def find(id, options = {})
        id = id.to_sym
        if options[:power_pin]
          pin = all_power_pins[id] || find_pin_group(id, options)
        elsif options[:ground_pin]
          pin = all_ground_pins[id] || find_pin_group(id, options)
        else
          pin = all_pins[id] || find_by_alias(id, options) || find_pin_group(id, options)
        end
        if pin
          if options[:ignore_context] || pin.enabled?(options)
            pin
          end
        end
      end

      def find_pin_group(id, options = {})
        options = {
          include_all: true
        }.merge(options)
        if options[:power_pin]
          base = all_power_pin_groups
        elsif options[:ground_pin]
          base = all_ground_pin_groups
        else
          base = all_pin_groups
        end
        pin_group_stores_in_context(base, options) do |store|
          return store[id] if store[id]
        end
        nil
      end

      # This will be called by the pins whenever a new alias is added to them
      def register_alias(id, pin, _options = {})
        known_aliases[id] ||= []
        known_aliases[id] << pin
      end

      # Find an existing pin group with the given ID if it exists and return it, otherwise create one
      def find_or_create_pin_group(id, owner, options = {})
        group = find_pin_group(id, options)
        unless group
          group = PinCollection.new(owner, options)
          group.id = id
          store_pin_group(group, options)
        end
        group
      end

      # Delete a specific pin
      def delete_pin(pin)
        if pin.is_a?(PowerPin)
          bank = all_power_pins
        elsif pin.is_a?(GroundPin)
          bank = all_ground_pins
        else
          bank = all_pins
        end
        # First delete the pin from any of the pin groups it resides
        Origen.pin_bank.pin_groups.each do |_name, grp|
          next unless grp.store.include?(pin)
          grp.delete(pin)
        end
        # Now delete the pin from the pin bank
        if bank[pin.id]
          bank.delete(pin.id)
          # Delete all known aliases as well
          known_aliases.delete(pin.name)
        else
          if pin.id == pin.name
            fail "A pin with id #{pin.id} does not exist!"
          else
            fail "A pin with id #{pin.id} and name #{pin.name} does not exist!"
          end
        end
      end

      # Delete a specific pin group
      def delete_pingroup(group)
        found_group = false
        if group.power_pins?
          base = all_power_pin_groups
        elsif group.ground_pins?
          base = all_ground_pin_groups
        else
          base = all_pin_groups
        end
        pin_group_stores_in_context(base) do |store|
          if store.include?(group.id)
            store.delete(group.id)
            found_group = true
          end
        end
        fail "A pin group with id #{group.id} does not exist!" unless found_group == true
      end

      private

      def current_pin_group_store(base, options)
        pin_group_stores_in_context(base, options)
      end

      def pin_group_stores_in_context(base, options = {})
        # Pin group availability is now only scoped by package
        options[:mode] = :all
        options[:configuration] = :all
        resolve_packages(options).each do |package|
          base[package] ||= {}
          resolve_modes(options).each do |mode|
            base[package][mode] ||= {}
            resolve_configurations(options).each do |config|
              base[package][mode][config] ||= {}
              if block_given?
                yield base[package][mode][config]
              else
                return base[package][mode][config]
              end
            end
          end
        end
      end

      def store_pin_group(group, options)
        if group.power_pins?
          base = all_power_pin_groups
        elsif group.ground_pins?
          base = all_ground_pin_groups
        else
          base = all_pin_groups
        end
        pin_group_stores_in_context(base, options) do |store|
          store[group.id] = group
        end
      end

      # Returns an array containing the package ids resolved from the given options or
      # the current top-level context
      def resolve_packages(options = {})
        p = [options.delete(:package) || options.delete(:packages) || current_package_id].flatten.compact
        if options[:include_all] || p.empty?
          p << :all
        end
        p.uniq
      end

      # Returns an array containing the mode ids resolved from the given options or
      # the current top-level context
      def resolve_modes(options = {})
        m = [options.delete(:mode) || options.delete(:modes) || current_mode_id].flatten.compact
        if options[:include_all] || m.empty?
          m << :all
        end
        m.uniq
      end

      # Returns an array containing the configuration ids resolved from the given options or
      # the current top-level context
      def resolve_configurations(options = {})
        c = [options.delete(:configuration) || options.delete(:configurations) || current_configuration].flatten.compact
        if options[:include_all] || c.empty?
          c << :all
        end
        c.uniq
      end

      # Returns the current configuration context for this pin/pin group, if a configuration has been
      # explicitly set on this pin that will be returned, otherwise the current chip-level configuration
      # context will be returned (nil if none is set)
      def current_configuration
        if Origen.top_level
          Origen.top_level.current_configuration
        end
      end

      # Returns the current top-level package ID, nil if none is set.
      def current_package_id
        if Origen.top_level && Origen.top_level.current_package
          Origen.top_level.current_package.id
        end
      end

      # Returns the current top-level mode ID, nil if none is set.
      def current_mode_id
        if Origen.top_level && Origen.top_level.current_mode
          Origen.top_level.current_mode.id
        end
      end

      def find_by_alias(id, options = {})
        if known_aliases[id]
          pins = known_aliases[id].select do |pin|
            pin.has_alias?(id, options)
          end
          if pins.size > 1
            fail "Mutliple pins with the alias #{id} have been found in the current scope!"
          end
          pins.first
        end
      end

      # Delete all pins, groups and aliases from the bank
      def empty!
        @all_ids = nil
        @known_aliases = nil
        @all_pins = nil
        @all_power_pins = nil
        @all_ground_pins = nil
        @all_pin_groups = nil
        @all_power_pin_groups = nil
        @all_ground_pin_groups = nil
      end

      def known_aliases
        @known_aliases ||= {}
      end

      def all_ids
        @all_ids ||= []
      end
    end
  end
end
