require 'active_support/concern'
require 'origen/memory'
require 'json'
module Origen
  # Include this module to identify it as an SoC IP Block, this will automatically
  # include common modules such as Pin and Register support
  module Model
    extend ActiveSupport::Concern

    autoload :Exporter, 'origen/model/exporter'

    included do
      attr_writer :ip_name
      attr_accessor :version
      attr_accessor :parent
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
      include Origen::Ports
      include Origen::Netlist
      include Origen::Memory
      include Origen::Errata
      include Origen::Fuses
      include Origen::Tests
      include Origen::PowerDomains
      include Origen::Clocks
      include Origen::Model::Exporter
      include Origen::Component
      include Origen::Limits
    end

    module ClassMethods
      def includes_origen_model
        true
      end
    end

    # Returns a frozen hash containing any attributes that were
    # derived from a block definition
    def attributes
      @attributes ||= {}.freeze
    end

    def inspect
      if controller
        "<Model/Controller: #{self.class}:#{object_id}/#{controller.class}:#{controller.object_id}>"
      else
        "<Model: #{self.class}:#{object_id}>"
      end
    end

    def is_an_origen_model?
      true
    end

    # Returns true if the instance is an Origen::Model that is wrapped
    # in a controller
    def is_a_model_and_controller?
      !!controller
    end

    # Returns true if the model is the current DUT/top-level model
    def is_top_level?
      respond_to?(:includes_origen_top_level?)
    end
    alias_method :is_dut?, :is_top_level?
    alias_method :top_level?, :is_top_level?

    # Means that when dealing with a controller/model pair, you can
    # always call obj.model and obj.controller to get the one you want,
    # regardless of the one you currently have.
    def model
      self
    end

    # Returns the application instance that defines the model, often the current app but it could
    # also be one of the plugins.
    # Returns nil if the application cannot be resolved, usually because the model's class has
    # not been correctly namespaced.
    def app
      @app ||= Origen::Application.from_namespace(self.class.to_s)
    end

    # Load the block definitions from the given path to the model.
    # Returns true if a block is found and loaded, otherwise nil.
    def load_block(path, options = {})
      options[:path] = path
      Origen::Loader.load_block(self, options)
    end

    def ==(obj)
      if obj.is_a?(Origen::SubBlocks::Placeholder)
        obj = obj.materialize
      end
      if controller
        super(obj) || controller.send(:==, obj, called_from_model: true)
      else
        super(obj)
      end
    end
    alias_method :equal?, :==

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
        controller_class = "#{klass}Controller"
        unless controller_class.start_with?('#<Class')
          # klass is an anonymous class. Can't support automatic resolution with anonymous classes
          if eval("defined? #{controller_class}")
            return eval(controller_class)
          elsif eval("defined? ::#{controller_class}")
            return eval("::#{controller_class}")
          end
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
      else
        unless top_level?
          # Need to do this in case a class besides SubBlock includes Origen::Model
          obj_above_self = parent.nil? ? Origen.top_level : parent
          return nil if obj_above_self.nil?
          if obj_above_self.current_mode
            _modes[obj_above_self.current_mode.id] if _modes.include? obj_above_self.current_mode.id
          end
        end
      end
    end
    alias_method :mode, :current_mode

    # Set the current mode configuration of the current model
    def current_mode=(id)
      @current_mode = id.is_a?(ChipMode) ? id.id : id
      Origen.app.listeners_for(:on_mode_changed).each do |listener|
        listener.on_mode_changed(mode: @current_mode, instance: self)
      end
      @current_mode
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

    def respond_to?(*args)
      super || !!(!@respond_directly && controller && controller.respond_to_directly?(*args))
    end

    def respond_to_directly?(*args)
      @respond_directly = true
      result = respond_to?(*args)
      @respond_directly = false
      result
    end

    # Used to proxy all method and attribute requests not implemented on the model
    # to the controller.
    #
    # On first call of a missing method a method is generated to avoid the missing lookup
    # next time, this should be faster for repeated lookups of the same method, e.g. reg
    def method_missing(method, *args, &block)
      if controller.respond_to?(method)
        define_singleton_method(method) do |*args, &block|
          controller.send(method, *args, &block)
        end
        send(method, *args, &block)
      else
        super
      end
    end

    # @api private
    # Returns true after the model's initialize method has been run
    def _initialized?
      !!@_initialized
    end

    def clock!
      clock_prepare
      clock_apply
    end

    def clock_prepare
      sub_blocks.each do |name, block|
        block.clock_prepare if block.respond_to?(:clock_prepare)
      end
    end

    def clock_apply
      sub_blocks.each do |name, block|
        block.clock_apply if block.respond_to?(:clock_apply)
      end
    end

    def to_json(*args)
      JSON.pretty_generate({
                             name:      name,
                             address:   base_address,
                             path:      path,
                             blocks:    sub_blocks.map do |name, block|
                               {
                                 name:    name,
                                 address: block.base_address
                               }
                             end,
                             registers: regs.map do |name, reg|
                               reg
                             end
                           }, *args)
    end

    private

    def _initialized
      @_initialized = true
    end

    def _controller=(controller)
      @controller = controller
    end

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
