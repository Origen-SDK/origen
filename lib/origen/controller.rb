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
          begin
            klass = eval("#{_namespace}::#{class_name}")
          rescue
            begin
              klass = eval(class_name)
            rescue
              begin
                klass = eval("#{self}::#{class_name}")
              rescue
                puts "Could not find class: #{class_name}"
                raise 'Unknown model class!'
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
      "Controller: <#{self.class}:#{object_id}>"
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
          eval(self.class.path_to_model)
        end
      end
    end

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

    # Used to proxy all method and attribute requests not implemented on the controller
    # to the model.
    #
    # On first call of a missing method a method is generated to avoid the missing lookup
    # next time, this should be faster for repeated lookups of the same method, e.g. reg
    def method_missing(method, *args, &block)
      if model.respond_to?(method)
        define_singleton_method(method) do |*args, &block|
          model.send(method, *args, &block)
        end
        send(method, *args, &block)
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
