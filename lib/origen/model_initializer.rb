module Origen
  module ModelInitializer
    extend ActiveSupport::Concern

    module ClassMethods
      # This overrides the new method of any class which includes this
      # module to force the newly created instance to be registered as
      # a top-level listener.
      def new(*args, &block) # :nodoc:
        options = args.find { |a| a.is_a?(Hash) } || {}

        x = allocate
        x.send(:init_top_level) if x.respond_to?(:includes_origen_top_level?)
        x.send(:init_sub_blocks, *args) if x.respond_to?(:init_sub_blocks)
        if x.respond_to?(:version=)
          version = options[:version]
          version ||= args.first if args.first.is_a?(Integer)
          x.version = version
        end
        if x.respond_to?(:parent=)
          parent = options.delete(:parent)
          x.parent = parent if parent
        end

        x.class.included_modules.each do |mod|
          mod.send(:origen_model_init, x) if mod.respond_to?(:origen_model_init)
          mod.constants.each do |constant|
            if mod.const_defined?(constant)
              mod.const_get(constant).send(:origen_model_init, x) if mod.const_get(constant).respond_to?(:origen_model_init)
            end
          end
        end

        options.each do |k, v|
          x.send(:instance_variable_set, "@#{k}", v) if x.respond_to?(k)
        end
        if x.respond_to?(:pre_initialize)
          if x.method(:pre_initialize).arity == 0
            x.send(:pre_initialize, &block)
          else
            x.send(:pre_initialize, *args, &block)
          end
        end
        if x.method(:initialize).arity == 0
          x.send(:initialize, &block)
        else
          x.send(:initialize, *args, &block)
        end
        if x.respond_to?(:is_an_origen_model?)
          x.send(:_initialized)
          Origen::Loader.load_block(x, options)
        end
        if x.respond_to?(:register_callback_listener)
          Origen.after_app_loaded do |app|
            x.register_callback_listener
          end
        end
        # Do this before wrapping, otherwise the respond to method in the controller will
        # be looking for the model to be instantiated when it is not fully done yet
        is_top_level = x.respond_to?(:includes_origen_top_level?)

        if x.respond_to?(:wrap_in_controller)
          x = x.wrap_in_controller
        end
        # If this object has been instantiated after on_create has already been called,
        # then invoke it now
        if Origen.application_loaded? && Origen.app.on_create_called?
          if x.try(:is_a_model_and_controller)
            m = x.model
            c = x.controller
            m.on_create if m.respond_to_directly?(:on_create)
            c.on_create if c.respond_to_directly?(:on_create)
          else
            x.on_create if x.respond_to?(:on_create)
          end
        end
        if is_top_level
          Origen.app.listeners_for(:on_top_level_instantiated, top_level: false).each do |listener|
            listener.on_top_level_instantiated(x)
          end
        end
        x
      end
    end
  end
end
