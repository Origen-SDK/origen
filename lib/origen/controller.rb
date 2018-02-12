module Origen
  module Controller
    extend ActiveSupport::Concern

    module ClassMethods
      def model(options = {})
        options[:controller_class] = self
        if options[:path]
          @path_to_model = options[:path]
        else
          options[:model_class] = _resolve_model_class(options)
        end
        Origen.controllers << options
      end

      def path_to_model
        @path_to_model
      end

      def _resolve_model_class(options)
        class_name = options[:class_name]
        if class_name
          if eval("defined? #{_namespace}::#{class_name}")
            klass = eval("#{_namespace}::#{class_name}")
          else
            if eval("defined? #{class_name}")
              klass = eval(class_name)
            else
              if eval("defined? #{self}::#{class_name}")
                klass = eval("#{self}::#{class_name}")
              else
                puts "Could not find class: #{class_name}"
                fail 'Unknown model class!'
              end
            end
          end
          klass
        else
          fail "You must supply a :class_name option when defining a controller's model!"
        end
      end

      def _namespace
        to_s.sub(/::[^:]*$/, '')
      end
    end

    def inspect
      if model
        "<Model/Controller: #{model.class}:#{model.object_id}/#{self.class}:#{object_id}>"
      else
        "<Controller: #{self.class}:#{object_id}>"
      end
    end

    def is_a?(*args)
      if model
        super(*args) || model.is_a?(*args)
      else
        super(*args)
      end
    end

    # Returns the controller's model
    def model
      @model ||= begin
        if self.class.path_to_model
          m = eval(self.class.path_to_model)
          if m
            if m.respond_to?(:_controller=)
              m.send(:_controller=, self)
            end
          else
            fail "No model object found at path: #{self.class.path_to_model}"
          end
          m
        end
      end
    end

    # When compared to another object, a controller will consider itself equal if either the controller
    # or its model match the given object
    def ==(obj, options = {})
      if obj.is_a?(Origen::SubBlocks::Placeholder)
        obj = obj.materialize
      end
      if options[:called_from_model]
        super(obj)
      else
        super(obj) || model == obj
      end
    end
    alias_method :equal?, :==

    # Means that when dealing with a controller/model pair, you can
    # always call obj.model and obj.controller to get the one you want,
    # regardless of the one you currently have.
    def controller
      self
    end

    def respond_to?(*args)
      super || !!(!@respond_directly && model && model.respond_to_directly?(*args))
    end

    def respond_to_directly?(*args)
      @respond_directly = true
      result = respond_to?(*args)
      @respond_directly = false
      result
    end

    def to_json(*args)
      model.to_json(*args)
    end

    # Used to proxy all method and attribute requests not implemented on the controller
    # to the model.
    #
    # On first call of a missing method a method is generated to avoid the missing lookup
    # next time, this should be faster for repeated lookups of the same method, e.g. reg
    def method_missing(method, *args, &block)
      if model.respond_to?(method)
        # This method is handled separately since it is important to produce a proxy method
        # that takes no arguments, otherwise the register address lookup system mistakes it
        # for a legacy way of calculating the base address whereby the register itself was
        # given as an argument.
        if method.to_sym == :base_address
          define_singleton_method(method) do
            model.send(method)
          end
          base_address
        else
          define_singleton_method(method) do |*args, &block|
            model.send(method, *args, &block)
          end
          send(method, *args, &block)
        end
      else
        super
      end
    end

    private

    def _model=(model)
      @model = model
    end
  end
end
