RSpec.shared_examples :componentable_bootup_spec do
  module ComponentableSpec
    module InitTests
    	class IncluderTestManual
     	  include Origen::Componentable
      end
      
      class IncluderTestModel
        include Origen::Model
        include Origen::Componentable
      end
      
      module ToIncludeWithModel
        class ToIncludeWithModel
          include Origen::Model
          include Origen::Componentable
        end
      end
      
      module ToIncludeWithoutModel
        class ToIncludeWithoutModel
          include Origen::Componentable
        end
      end
      
      class ParentNoModel
        include ToIncludeWithModel
        
        def initialize
        end
      end
      
      class ParentNoModelInit
        include ToIncludeWithModel
        
        def initialize
          ToIncludeWithModel::ToIncludeWithModel.new
          Origen::Componentable.init_parent_class(self, ToIncludeWithModel::ToIncludeWithModel)
        end
      end
      
      class Init_Parent_With_Model_Component_Without
        include Origen::Model
        include TestComponentWithoutModel
      end
      
      class Init_Parent_And_Component_With_Model
        include Origen::Model
        include TestComponent
      end
      
      # Instantiating this class should result in a Origen::Componentable::Error exception
      class InitParentWithSingletonMethodDefined
        include Origen::Model
        include TestComponent
        
        def test_component
          "hi"
        end
      end
      
      # Instantiating this class should result in three warnings.
      class InitParentWithParentMethodsDefined
        include Origen::Model
        include TestComponent
        
        def test_components
          "hi"
        end
        
        def add_test_component
          "hi"
        end
        
        def each_test_component
          "hi"
        end
      end
      
    end
  end

  describe 'Bootup Spec - Check that Componentable is booting up as expected' do
  
    # Componetable.componentable_container_name summary:
    #  gets the name of the componentable container name at runtime
    
    # Componentable.init_includer_class summary:
    #  initializes the componentable objects/methods on the includer. Ex:
    #  class includer
    #    include Compomentable
    #    def initialize
    #      #=> includer.includers #=> no method exception
    #      #=> includer.respond_to?(:add) #=> false
    #
    #      Origen::Componentable.init_includer_class(self) #=> this is auto-called if Origen::Model is included
    #      #=> includer.includers #=> {}
    #      #=> includer.respond_to?(:add) #=> true
    #  ...
    describe 'Method: Componentable.init_includer_class' do
      it 'initially does not have a componentable_container' do
      	i = ComponentableSpec::InitTests::IncluderTestManual.new
      	i.respond_to?(:includers).should == false
      end
      
      it 'initializes the includer after calling Componentable.init_includer_class' do
      	i = ComponentableSpec::InitTests::IncluderTestManual.new
      	i.respond_to?(:includer_test_manuals).should == false
      	
      	Origen::Componentable.init_includer_class(i)
      	i.instance_variable_defined?(:@_componentable_container).should == true
      	i._componentable_container.should == {}
      	i.respond_to?(:includer_test_manuals).should == true
      	i.includer_test_manuals.should == {}
      end
      
      it 'initializes automatically if the includer also includes Origen::Model' do
      	i = ComponentableSpec::InitTests::IncluderTestModel.new
      	
      	i.respond_to?(:includer_test_models).should == true
      	i.includer_test_models.should == {}
      end
      
      context 'with anonymous classes/modules' do
        it 'detects that it\'s an anonymous class and complains that the constant COMPONENTABLE_SINGLETON_NAME must be defined' do
          includer_class = Class.new do
            include Origen::Model
            include Origen::Componentable
          end
          
          expect { includer_class.new }.to raise_error Origen::Componentable::Error,
            /Anonymous classes that include the Componentable module must define COMPONENTABLE_SINGLETON_NAME/
        end
        
        it 'still complains if COMPONENTABLE_PLURAL_NAME is defined but COMPONENTABLE_SINGLETON_NAME is not' do
          includer_class = Class.new do
            include Origen::Model
            include Origen::Componentable
            
            self.const_set(:COMPONENTABLE_PLURAL_NAME, "plural_tester")
          end
          
          expect { includer_class.new }.to raise_error Origen::Componentable::Error,
            /Anonymous classes that include the Componentable module must define COMPONENTABLE_SINGLETON_NAME, even if COMPONENTABLE_PLURAL_NAME is defined/
        end
        
        it 'can initiailize an anonymous class with COMPONENTABLE_SINGLETON_NAME defined' do
          includer_class = Class.new do
            include Origen::Model
            include Origen::Componentable
            
            self.const_set(:COMPONENTABLE_SINGLETON_NAME, "singleton_tester")
          end
          
          i = includer_class.new
          expect(i).to respond_to(:singleton_testers)
        end
        
        it 'can initiailize an anonymous class with both COMPONENTABLE_SINGLETON_NAME and COMPONENTABLE_PLURAL_NAME defined' do
          includer_class = Class.new do
            include Origen::Model
            include Origen::Componentable
            
            self.const_set(:COMPONENTABLE_SINGLETON_NAME, "singleton_testa")
            self.const_set(:COMPONENTABLE_PLURAL_NAME, 'plural_testa')
          end
          
          i = includer_class.new
          expect(i).to respond_to(:plural_testa)
        end
        
        it 'complains if COMPONENTABLE_SINGLETON_NAME and COMPONENTABLE_PLURAL_NAME are the same' do
          includer_class = Class.new do
            include Origen::Model
            include Origen::Componentable
            
            self.const_set(:COMPONENTABLE_SINGLETON_NAME, 'same_name')
            self.const_set(:COMPONENTABLE_PLURAL_NAME, 'same_name')
          end
          
          expect { includer_class.new }.to raise_error Origen::Componentable::Error,
            /Componentable including class cannot define both COMPONENTABLE_SINGLETON_NAME and COMPONENTABLE_PLURAL_NAME to 'same_name'/
        end
      end
    end
      
    # Componetable.init_parent_class summary:
    #  initializes the includer class's compomentable methods on its
    #  parent.
    #  class parent_of_includer
    #    include Includer #=> includes Componentable
    #
    #    def initialize
    #      #=> includers #=> no method exception
    #      #=> self.respond_to?(:add_includer) #=> false
    #
    #      Origen::Componentable.init_parent_class(self) #=> this is auto-called if Origen::Model is included
    #      #=> includers #=> {}
    #      #=> self.respond_to?(:add_includer) #=> true
    #    ..
    describe 'Method: Componentable.init_parent_class' do
          
      it 'initially does not have a \'parent_no_model\' method' do
        c = ComponentableSpec::InitTests::ParentNoModel.new
        c.respond_to?(:parent_no_model).should == false
      end
      
      it 'initializes the includer setup after calling Componentable.init_parent_class' do
        c = ComponentableSpec::InitTests::ParentNoModelInit.new
        c.respond_to?(:to_include_with_model).should == true
        expect(c.to_include_with_model).to be_a(ComponentableSpec::InitTests::ToIncludeWithModel::ToIncludeWithModel)
      end
      
      it 'Bootstraps calling Componentable.init_parent_class if it includes Origen::Model, but there may be issues ' \
          'if the Componentable class does not include Origen::Model' do
          # Need to work on this since this is a bit dangerous. This ends up booting the parent class
          # but not boot the componentable class. So, the parent class has all the methods, but they'll all
          # fail at the componentable-class's level.
          # For now though, the following shows what will happen.
          c = ComponentableSpec::InitTests::Init_Parent_With_Model_Component_Without.new
          expect(c).to respond_to(:test_component)
          expect(c.test_component).to_not respond_to(:_componentable_container)
      end
      
      it 'Bootstraps calling Componentable.init_parent_class if it includes Origen::Model and works as expected' \
          'if the Componentable class does too' do
          c = ComponentableSpec::InitTests::Init_Parent_And_Component_With_Model.new
          
          c.respond_to?(:test_component).should == true
          expect(c.test_component).to be_a(ComponentableSpec::TestComponent::TestComponent)
      end
      
      context 'With anonymous classes' do
        it 'can initialize an anonymous parent without any additional setup' do
          parent_class = Class.new do
            include Origen::Model
            include ComponentableSpec::TestComponent
          end
          
          parent = parent_class.new
          expect(parent).to respond_to(:test_components)
          expect(parent).to respond_to(:test_component)
          expect(parent.test_component).to be_a(ComponentableSpec::TestComponent::TestComponent)
          expect(parent.test_components).to eql({})
        end
      end
      
      context 'with user-defined componentable names' do
        # These tests are mostly accomplished from the componentable_includer_init, but just double check here.
        before :context do
          @parent = Class.new do
            include Origen::Model
            include ComponentableSpec::ComponentableNamesTests
          end.new
        end
       
        it 'will initialize the API with COMPONENTABLE_SINGLETON_NAME defined' do
          expect(@parent).to_not respond_to(:test_component_singleton_defined)
          expect(@parent).to_not respond_to(:test_component_singleton_defineds)
          expect(@parent).to respond_to(:test_singleton_name)
          expect(@parent).to respond_to(:test_singleton_names)

          expect(@parent.test_singleton_name).to be_a(ComponentableSpec::ComponentableNamesTests::TestComponentSingletonDefined)
          expect(@parent.test_singleton_names).to eql({})
        end
        
        it 'will initialize the API with COMPONENTABLE_PLURAL_NAME defined' do
          expect(@parent).to respond_to(:test_component_plural_defined)
          expect(@parent).to respond_to(:test_plural_names)
          expect(@parent).to_not respond_to(:test_component_plural_defineds)
          
          expect(@parent.test_component_plural_defined).to be_a(ComponentableSpec::ComponentableNamesTests::TestComponentPluralDefined)
          expect(@parent.test_plural_names).to eql({})
        end
                
        it 'will initialize the API with both COMPONENTABLE_SINGLETON_NAME and COMPONENTABLE_PLURAL_NAME defined' do
          expect(@parent).to_not respond_to(:test_component_both_defined)
          expect(@parent).to_not respond_to(:test_component_both_defineds)
          
          expect(@parent).to respond_to(:test_both_names_singleton)
          expect(@parent).to_not respond_to(:test_both_names_singletons)
          
          expect(@parent).to respond_to(:test_both_names_plural)
          expect(@parent.test_both_names_singleton).to be_a(ComponentableSpec::ComponentableNamesTests::TestComponentBothDefined)
          expect(@parent.test_both_names_plural).to eql({})
        end
      end
    end
    
    context 'with some methods defined by the parent already' do
      
      it 'fails if the singleton name is alredy taken' do
        expect {
          ComponentableSpec::InitTests::InitParentWithSingletonMethodDefined.new
        }.to raise_error Origen::Componentable::Error, 'Class ComponentableSpec::InitTests::InitParentWithSingletonMethodDefined provides a method :test_component already. Cannot include Componentable class ComponentableSpec::TestComponent::TestComponent in this object!'
      end
      
      it 'warns if any of the other generic methods already exists' do
        l1 = "Componentable: Parent class ComponentableSpec::InitTests::InitParentWithParentMethodsDefined already defines a method test_components. This method will not be used by Componentable"
        l2 = "Componentable: Parent class ComponentableSpec::InitTests::InitParentWithParentMethodsDefined already defines a method add_test_component. This method will not be used by Componentable"
        l3 = "Componentable: Parent class ComponentableSpec::InitTests::InitParentWithParentMethodsDefined already defines a method each_test_component. This method will not be used by Componentable"
                                                                                                  # http://rubular.com/r/jOmctDGhvR
        expect { ComponentableSpec::InitTests::InitParentWithParentMethodsDefined.new }.to output(/#{l1}.*\n.*#{l2}.*\n.*#{l3}/).to_stdout_from_any_process
      end
    end
  end
end
