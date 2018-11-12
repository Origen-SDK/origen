module Origen
  module Pins
    require 'delegate'
    require 'origen/pins/pin'
    # Thin wrapper around pin objects to implement a defined function.
    #
    # The pin object stores all attributes associated with the function, this
    # wrapper simply keeps track of what function a given pin reference refers to
    class FunctionProxy < ::Delegator
      def initialize(id, pin)
        @id = id
        @pin = pin
      end

      def __getobj__
        @pin
      end

      # @api private
      #
      # To play nicely with == when a function proxy is wrapping a pin that is already
      # wrapped by an OrgFile interceptor
      def __object__
        @pin.__object__
      end

      # Intercept all calls to function-scoped attributes of the pin so
      # that we can inject the function that we want the attribute value for
      Pin::FUNCTION_SCOPED_ATTRIBUTES.each do |attribute|
        define_method attribute do |options = {}|
          options[:function] = @id
          @pin.send(attribute, options)
        end
      end

      private

      # For debug
      def _function
        @id
      end
    end
  end
end
