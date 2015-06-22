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
          version ||= args.first if args.first.is_a?(Fixnum)
          x.version = version
        end
        if x.respond_to?(:parent=)
          parent = options.delete(:parent)
          x.parent = parent if parent
        end
        if x.method(:initialize).arity == 0
          x.send(:initialize, &block)
        else
          x.send(:initialize, *args, &block)
        end
        x.register_callback_listener if x.respond_to?(:register_callback_listener)
        # Do this before wrapping, otherwise the respond to method in the controller will
        # be looking for the model to be instantiated when it is not fully done yet
        is_top_level = x.respond_to?(:includes_origen_top_level?)
        if x.respond_to?(:wrap_in_controller)
          x = x.wrap_in_controller
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
