require 'active_support/concern'
module Origen
  # Include this module to identify it as an SoC IP Block, this will automatically
  # include common modules such as Pin and Register support
  module Model
    extend ActiveSupport::Concern

    included do
      attr_writer :ip_name
      attr_accessor :version
      attr_reader :controller

      include Origen::ModelInitializer
      include Origen::Pins
      include Origen::Registers
      include Origen::Callbacks
      include Origen::Bugs
      include Origen::Features
      include Origen::SubBlocks
      include Origen::Parameters
      include Origen::Specs
    end

    module ClassMethods
      def includes_origen_model
        true
      end
    end

    def log
      Origen.log
    end

    def write_memory(*args)
      return super if defined?(super)
      write_register(*args)
    end

    def read_memory(*args)
      return super if defined?(super)
      read_register(*args)
    end

    def ip_name
      @ip_name || self.class.to_s.split('::').last.symbolize
    end

    def wrap_in_controller
      c = Origen.controllers.find do |params|
        self.is_a?(params[:model_class]) if params[:model_class]
      end
      if c
        c = c[:controller_class].send(:allocate)
        if c.method(:initialize).arity == 0
          c.send(:initialize)
        else
          c.send(:initialize, self)
        end
        c.send('_model=', self)
        @controller = c
        c
      else
        controller_class = _resolve_controller_class
        if controller_class
          c = controller_class.send(:allocate)
          if c.method(:initialize).arity == 0
            c.send(:initialize)
          else
            c.send(:initialize, self)
          end
          c.extend(Origen::Controller)
          c.send('_model=', self)
          @controller = c
          c
        else
          self
        end
      end
    end

    def _resolve_controller_class
      klass = self.class
      while klass != Object
        model_class = klass.to_s.split('::').last
        controller_class = "#{model_class}Controller"
        if eval("defined? #{controller_class}")
          return eval(controller_class)
        elsif eval("defined? ::#{controller_class}")
          return eval("::#{controller_class}")
        end
        klass = klass.superclass
      end
    end

    def current_configuration
      if self.respond_to?(:configuration)
        configuration
      end
    end

    def configuration=(id)
      add_configuration(id)
      @configuration = id
    end

    def configuration
      @configuration
    end

    def add_configuration(id)
      configurations << id unless configurations.include?(id)
    end

    # Returns an array containing the IDs of all known configurations
    def configurations
      @configurations ||= []
    end

    # Execute the supplied block within the context of the given configuration, at the end
    # the model's configuration attribute will be restored to what it was before calling
    # this method.
    def with_configuration(id, _options = {})
      orig = configuration
      self.configuration = id
      yield
      self.configuration = orig
    end

    # Returns the current mode/configuration of the top level SoC. If no mode has been specified
    # yet this will return nil
    #
    #   $dut = DUT.new
    #   $dut.mode             # => default
    #   $dut.mode.default?    # => true
    #   $dut.mode.ram_bist?   # => false
    #   $dut.mode = :ram_bist
    #   $dut.mode.default?    # => false
    #   $dut.mode.ram_bist?   # => true
    def current_mode
      if @current_mode
        return _modes[@current_mode] if _modes[@current_mode]
        fail "The mode #{@current_mode} of #{self.class} has not been defined!"
      end
    end
    alias_method :mode, :current_mode

    # Set the current mode configuration of the current model
    def current_mode=(id)
      @current_mode = id.is_a?(ChipMode) ? id.id : id
    end
    alias_method :mode=, :current_mode=

    def add_mode(id, options = {})
      m = ChipMode.new(id, options)
      m.owner = self
      yield m if block_given?
      _add_mode(m)
      m
    end

    def has_mode?(id)
      !!(_modes[id.is_a?(ChipMode) ? id.id : id])
    end

    # Returns an array containing the IDs of all known modes if no ID is supplied,
    # otherwise returns an object representing the given mode ID
    def modes(id = nil, _options = {})
      id = nil if id.is_a?(Hash)
      if id
        _modes[id]
      else
        _modes.ids
      end
    end

    # Executes the given block of code within the context of the given mode, at the end
    # the mode will be restored back to what it was on entry
    def with_mode(id, _options = {})
      orig = mode
      self.mode = id
      yield
      self.mode = orig
    end

    # Executes the given block of code for each known chip mode, inside the block
    # the current mode of the top level block will be set to the given mode.
    #
    # At the end of the block the current mode will be restored to whatever it
    # was before entering the block.
    def with_each_mode
      begin
        orig = current_mode
      rescue
        orig = nil
      end
      modes.each do |_id, mode|
        self.current_mode = mode
        yield mode
      end
      self.current_mode = orig
    end
    alias_method :each_mode, :with_each_mode

    # Sets the modes array to nil.  Written so modes created in memory can
    # be erased so modes defined in Ruby files can be loaded
    def delete_all_modes
      @_modes = nil
    end
    alias_method :del_all_modes, :delete_all_modes

    # Returns all specs found for the model.  if none found it returns an empty array
    def find_specs
      specs_found = []
      # Check for specs the object owns
      if self.respond_to? :specs
        object_specs = specs
        unless object_specs.nil?
          if object_specs.class == Origen::Specs::Spec
            specs_found << object_specs
          else
            specs_found.concat(object_specs)
          end
        end
      end
      sub_blocks.each do |_name, sb|
        next unless sb.respond_to? :specs
        child_specs = sb.specs
        unless child_specs.nil?
          if child_specs.class == Origen::Specs::Spec
            specs_found << child_specs
          else
            specs_found.concat(child_specs)
          end
        end
      end
      specs_found
    end

    # Delete all specs and notes for self recursively
    def delete_all_specs_and_notes(obj = nil)
      obj = self if obj.nil?
      obj.delete_all_specs
      obj.delete_all_notes
      obj.delete_all_exhibits
      obj.children.each do |_name, child|
        next unless child.has_specs?
        delete_all_specs_and_notes(child)
      end
    end

    private

    def _modes
      @_modes ||= {}
    end

    def _add_mode(mode)
      if _modes[mode.id]
        fail "There is already a mode called #{mode.id}!"
      else
        _modes[mode.id] = mode
      end
    end
  end
  # Legacy API
  IPBlock = Model
end
