module Origen
  module Parameters
    # An instance of this class is returned whenever the parameter context is set to
    # a value for which no parameter set has been defined.
    #
    # Sometime this may be valid in the case where the context is actually implemented
    # by another object which shadows the context.
    #
    # The missing allows the user to do params.context to retrieve the value of the
    # current context, but it will error out with a useful error message if they try
    # to do anything else (i.e. retrieve a parameter from it)
    class Missing
      attr_reader :owner

      def initialize(options = {})
        @owner = options[:owner]
      end

      def context
        owner._parameter_current
      end

      def method_missing(_method, *_args, &_block)
        owner.send(:_validate_parameter_set_name, context)
      end
    end
  end
end
