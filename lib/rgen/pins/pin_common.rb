module RGen
  module Pins
    # Methods and attributes that are common to both pins
    # and pin groups
    module PinCommon
      extend ActiveSupport::Concern

      included do
        attr_reader :id
        attr_reader :owner
        # Returns a hash containing the chip packages that the given pin is present in and a metadata hash for each package option containing
        # information like the location or pin number for the given in pin in the given package.
        attr_reader :packages
        # Returns a hash containing the chip modes that the given pin is present in and a metadata hash for storing any information
        # specific to the operation of the given pin in that mode
        attr_reader :modes
        # Returns a hash containing the chip configurations that the given pin is present in and a metadata hash for storing any information
        # specific to the operation of the given pin in that configuration
        attr_reader :configurations
        # Override the chip-level configuration attribute for the given pin
        attr_accessor :configuration
        # Free format field to store an description of the pin or pin group function
        attr_accessor :description
      end

      def to_sym
        id
      end

      # The ID of a pin should be considered immutable, however internally it may be neccessary
      # to change the initial ID as the pins are initially setup
      #
      # @api private
      def id=(val)
        if @id && @finalized
          fail 'The ID of a pin cannot be changed once it has been set!'
        else
          @id = val
        end
      end

      # @api private
      def finalize
        @finalized = true
      end

      # Returns true if the pin is enabled by the current or given context
      def enabled?(options = {})
        present_in_package?(options) # && enabled_in_mode?(options) && enabled_in_configuration?(options)
      end

      # Returns true if the pin or pin group is present in the current package context.
      #
      # A pin is considered enabled when either no package context is set (all pins available
      # at die level), or when a package context is set and it matches one attached to the pin
      def enabled_in_package?(options = {})
        package = options[:package] || current_package_id
        if package
          !!(packages[:all] || packages[package])
        else
          true
        end
      end
      alias_method :present_in_package?, :enabled_in_package?

      # Returns true if the pin or pin group is present in the current mode context.
      def enabled_in_mode?(options = {})
        mode = options[:mode] || current_mode_id
        if mode
          !!(modes[:all] || modes.empty? || modes[mode])
        # If no mode is specified a pin is only available if it does not have a mode constraint
        else
          !!(modes[:all] || modes.empty?)
        end
      end

      # Returns true if the pin or pin group is present in the current configuration context.
      def enabled_in_configuration?(options = {})
        config = options[:configuration] || current_configuration
        if config
          !!(configurations[:all] || configurations.empty? || configurations[config])
        # If no configuration is specified a pin is only available if it does not have a configuration constraint
        else
          !!(configurations[:all] || configurations.empty?)
        end
      end

      # Make the pin available in the given package, any options that are supplied will be
      # saved as metadata associated with the given pin in that package
      def add_package(id, options = {})
        packages[id] = options
        if is_a?(Pin)
          add_location(options[:location], package: id) if options[:location]
        end
      end

      # Make the pin or pin group available in the given mode, any options that are supplied will be
      # saved as metadata associated with the given pin in that mode
      def add_mode(id, options = {})
        modes[id] = options
      end

      # Make the pin or pin group available in the given configuration, any options that are supplied will be
      # saved as metadata associated with the given pin in that configuration
      def add_configuration(id, options = {})
        configurations[id] = options
      end

      private

      def on_init(owner, options = {})
        @owner = owner
        @description = options[:description]
        apply_initial_scope(options)
      end

      # Returns the current configuration context for this pin/pin group, if a configuration has been
      # explicitly set on this pin that will be returned, otherwise the current chip-level configuration
      # context will be returned (nil if none is set)
      def current_configuration
        configuration || begin
          if RGen.top_level
            RGen.top_level.current_configuration
          end
        end
      end

      # Returns the current top-level package ID, nil if none is set.
      def current_package_id
        if RGen.top_level && RGen.top_level.current_package
          RGen.top_level.current_package.id
        end
      end

      # Returns the current top-level mode ID, nil if none is set.
      def current_mode_id
        if RGen.top_level && RGen.top_level.current_mode
          RGen.top_level.current_mode.id
        end
      end

      def apply_initial_scope(options)
        @packages = {}
        @modes = {}
        @configurations = {}
        add_initial_packages(options)
        add_initial_modes(options)
        add_initial_configurations(options)
      end

      # Returns an array containing the package ids resolved from the given options or
      # the current top-level context
      def resolve_packages(options = {})
        [options.delete(:package) || options.delete(:packages) || current_package_id].flatten.compact
      end

      # Returns an array containing the mode ids resolved from the given options or
      # the current top-level context
      def resolve_modes(options = {})
        [options.delete(:mode) || options.delete(:modes) || current_mode_id].flatten.compact
      end

      # Returns an array containing the configuration ids resolved from the given options or
      # the current top-level context
      def resolve_configurations(options = {})
        [options.delete(:configuration) || options.delete(:configurations) || current_configuration].flatten.compact
      end

      def add_initial_packages(options)
        resolve_packages(options).each do |package|
          if package.is_a?(Hash)
            package.each do |id, attributes|
              add_package(id, attributes)
            end
          else
            add_package(package)
          end
        end
      end

      def add_initial_modes(options)
        resolve_modes(options).each do |mode|
          if mode.is_a?(Hash)
            mode.each do |id, attributes|
              add_mode(id, attributes)
            end
          else
            add_mode(mode)
          end
        end
      end

      def add_initial_configurations(options)
        resolve_configurations(options).each do |config|
          if config.is_a?(Hash)
            config.each do |id, attributes|
              add_configuration(id, attributes)
            end
          else
            add_configuration(config)
          end
        end
      end
    end
  end
end
