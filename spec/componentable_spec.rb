require "spec_helper"

# Using some pretty generic names, so just to make sure it won't conflict with other classes.
module ComponentableSpec
  module TestComponent
    class TestComponent
      include Origen::Model
      include Origen::Componentable
      
      COMPONENTABLE_ADDS_ACCESSORS = true
    end
  end

  module TestComponentWithoutModel
    class TestComponent
      include Origen::Componentable
    end
  end
  
  module ComponentableNamesTests
    class TestComponentPluralDefined
      include Origen::Model
      include Origen::Componentable
      
      COMPONENTABLE_PLURAL_NAME = 'test_plural_names'
    end
    
    class TestComponentSingletonDefined
      include Origen::Model
      include Origen::Componentable
      
      COMPONENTABLE_SINGLETON_NAME = 'test_singleton_name'
    end
    
    class TestComponentBothDefined
      include Origen::Model
      include Origen::Componentable
      
      COMPONENTABLE_SINGLETON_NAME = 'test_both_names_singleton'
      COMPONENTABLE_PLURAL_NAME = 'test_both_names_plural'
    end
  end

  fdescribe 'Componentable' do
    include_examples :componentable_namer_spec
    include_examples :componentable_bootup_spec
    include_examples :componentable_includer_spec
    include_examples :componentable_parent_spec
  end
end

