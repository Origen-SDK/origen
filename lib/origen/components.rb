module Origen

  # API for dealing with instantiating and keeping track of components or
  # 'component-like object' (e.g. sub blocks).
  # This API can be included as a mixin and extended further extended by the includer
  # to get the top-level component behavior while providing more refined usage at the same time.
  module Component
  
    # Componentable Component class. This is the general purpose container to just 'add a thing'
    class Component
      include Origen::Componentable
      
      # Kind of ironic really, but since we're auto-including this when Origen::Model is included,
      # we can't include Origen::Model here or else we'll get a circular dependency.
      # Note that the parent will still initialize correctly, but we need to initialize Components manually.
      # I.e, the parent will get methods :component, :add_components, :components, etc., but the Component object
      # won't be initialized so everything will fail.
      def initialize
        Origen::Componentable.init_includer_class(self)
      end
    end
    
    # Default class instantiate if the class_name is not provided
    class Default
      include Origen::Model
      
      attr_reader :options
      
      def initialize(options={})
        @options = options
      end
    end
  end
  
end
