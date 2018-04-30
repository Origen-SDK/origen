require_relative '../pins'
module Origen
  module Pins
    # Creates pin groups using a mix of regular expressions, arrays
    # and Symbols, with the option to make package(s) specific pin groups
    class PinGroupsCreator
      include Origen::Pins

      CurrentGroup = Struct.new(:id, :pins)

      attr_accessor :packages, :_current_group

      def initialize(packages = nil, &block)
        if packages.nil?
          # Assign the pin group at the die level
          @packages = []
        else
          packages = [packages] unless packages.is_a?(Array)
          fail unless packages_defined?(packages)
          @packages = packages
        end
        (block.arity < 1 ? (instance_eval(&block)) : block.call(self)) if block_given?
      end

      def add_group(id, *args, &block)
        if block_given?
          @_current_group = CurrentGroup.new(id)
          yield
        else
          # Loop through the args and find the pin(s) specified by each args
          pins_found = evaluate_args(args)
          fail unless pins_found_ok?(pins_found)
          add_group_to_model id, pins_found
        end
      end
      alias_method :group, :add_group

      def with(*args)
        if @_current_group.pins.nil?
          pins_found = evaluate_args(args)
          fail unless pins_found_ok?(pins_found)
          @_current_group.pins = evaluate_args(args)
        else
          Origen.log.error("Pins found for the current pin group definition '#{@_current_group.id}', multiple 'with' method declarations not supported!")
          fail
        end
      end

      def without(*args)
        if @_current_group.pins.empty?
          Origen.log.error('You cannot exclude pins from a pin group before adding any!')
          fail
        end
        pins_found = evaluate_args(args)
        fail unless pins_found_ok?(pins_found)
        if @packages.empty?
          remaining_pins = @_current_group.pins[:die] - pins_found[:die]
          @_current_group.pins = { die: remaining_pins }
        else
          remaining_pins_per_pkg = {}.tap do |pins_hash|
            @packages.each do |pkg|
              remaining_pins = @_current_group.pins[pkg] - pins_found[pkg]
              pins_hash[pkg] = remaining_pins
            end
          end
          @_current_group.pins = remaining_pins_per_pkg
        end
        add_group_to_model @_current_group.id, @_current_group.pins
        @_current_group = nil
      end

      private

      def add_group_to_model(id, pins)
        if @packages.empty?
          add_pin_group id, *pins[:die]
        else
          @packages.each do |pkg|
            add_pin_group id, *pins[pkg], package: pkg
          end
        end
      end

      def pins_found_ok?(pin_hash)
        return_value = true
        pin_hash.each do |pkg, pin_list|
          error_str = (pkg == :die) ? 'at the die level' : "for package '#{pkg}'"
          if pin_list.dups?
            Origen.log.error("Cannot create pin group '#{id}' #{error_str}, found duplicate pins: #{pin_list.dups}!")
            return_value = false
          end
          if pin_list.empty?
            Origen.log.error("Cannot create pin group '#{id}' #{error_str}, found no pins!")
            return_value = false
          end
        end
        return_value
      end

      def evaluate_args(args)
        pins_per_pkg = {}.tap do |pkg_hash|
          if @packages.empty?
            pkg_hash[:die] = create_pins_array(args)
          else
            @packages.each do |pkg|
              pkg_hash[pkg] = create_pins_array(args, package: pkg)
            end
          end
        end
      end

      def create_pins_array(args, options = {})
        Origen.top_level.package = options[:package] if options[:package]
        pins_found = [].tap do |pins_ary|
          args.each do |arg|
            case arg
            when Symbol
              # Check for an existing pin or pingroup
              if pin_type?(arg).nil?
                Origen.log.error("Cannot find any pins that match '#{arg}'!")
                fail
              else
                pins_ary << find_matching_pins(arg)
              end
            when Array
              # Check for an existing pin or pingroup for each item in array
              arg.each do |pin_expr|
                case pin_expr
                when Symbol
                  if pin_type?(pin_expr).nil?
                    Origen.log.error("Cannot find any pin or pingroup that match '#{pin_expr}'!")
                    fail
                  else
                    pins_ary << pin_expr
                  end
                when Regexp
                  pins_ary << find_matching_pins(pin_expr)
                else
                  Origen.log.error('Only Symbols or Regexp can be elements in a pin group array definition!')
                  fail
                end
              end
            when Regexp
              pins_ary << find_matching_pins(arg)
            end
          end
        end.flatten
        Origen.top_level.package = nil
        pins_found
      end

      def find_matching_pins(pin_expr, options = {})
        Origen.top_level.package = options[:package] if options[:package]
        pins_found = case pin_expr
        when Regexp
          # Find all matching pin(s) or pingroup(s) for the regular expression
          matching_pins = Origen.top_level.pins.select { |pin_id, pin_obj| pin_id.smatch(/#{pin_expr}/) }
          if matching_pins.empty?
            Origen.log.error("Cannot find any pins that match '#{pin_expr.to_txt}'!")
            fail
          else
            matching_pins.ids
          end
        else
          pin_type = pin_type?(pin_expr)
          if pin_type.nil?
            Origen.log.error("Cannot find any pins that match '#{pin_expr}'!")
            fail
          elsif pin_type == :group
            # Return the pins in the pingroup
            Origen.top_level.pins(pin_expr).map(&:id)
          else
            pin_expr
          end
        end
        Origen.top_level.package = nil
        pins_found
      end

      def pin_type?(pin, options = {})
        pin_type = nil
        Origen.top_level.package = options[:package] if options[:package]
        if Origen.top_level.pins.include?(pin)
          pin_type = :signal
        elsif Origen.top_level.pin_groups.include?(pin)
          pin_type = :group
        elsif Origen.top_level.power_pins.include?(pin)
          pin_type = :power
        elsif Origen.top_level.ground_pins.include?(pin)
          pin_type = :ground
        elsif Origen.top_level.virtual_pins.include?(pin)
          pin_type = :virtual
        end
        Origen.top_level.package = nil
        pin_type
      end

      def packages_defined?(packages)
        packages.each do |pkg|
          return false unless packages.include?(pkg)
        end
        true
      end
    end
  end
end
