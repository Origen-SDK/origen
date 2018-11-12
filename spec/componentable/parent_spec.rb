RSpec.shared_examples :componentable_parent_spec do
  module ComponentableSpec
    class AddTest
      attr_reader :opts
      
      def initialize(options = {})
        @opts = options
      end
    end
    
    module ComponentableParentInitTest
      class InitWithModel
        include Origen::Model
        include TestComponent
      end
      
      #class InitWithoutModel
      #end
      
      #class Init_Parent_With_Model_Component_Without
      #  include Origen::Model
      #  include ComponentableSpec::TestComponentWithoutModel
      #end
    end
    
    module ComponentableAccessorTests
      class TestDefault
        include Origen::Model
        include Origen::Componentable
      end
      
      class TestTrue
        COMPONENTABLE_ADDS_ACCESSORS = true
        include Origen::Model
        include Origen::Componentable
      end
      
      class TestFalse
        COMPONENTABLE_ADDS_ACCESSORS = false
        include Origen::Model
        include Origen::Componentable
      end
    end
    
    module ComponentableAccessorTestParents
      class Parent
        include Origen::Model
        include ComponentableAccessorTests
        include TestComponent
      end
      
      class ParentDisableAccessorsReader
        include Origen::Model
        include ComponentableAccessorTests
        include TestComponent
        
        attr_reader :disable_componentable_accessors
        
        def initialize(option={})
          @disable_componentable_accessors = true
        end
        
        def test_add
          "Hi!"
        end
      end
      
      class ParentDisableAccessorsMethod
        include Origen::Model
        include ComponentableAccessorTests
        include TestComponent
        
        def disable_componentable_accessors(class_name)
          if class_name == ComponentableSpec::ComponentableAccessorTests::TestTrue
            true
          else
            false
          end
        end
      end
    end
  end
  
  describe 'Parent API Spec' do
  
    context 'with ComponentableTest class InitWithModel include TestComponent' do
      before :context do
        @parent = ComponentableSpec::ComponentableParentInitTest::InitWithModel.new
      end
      
      it 'has the componentable_test object' do
        @parent.respond_to?(:test_component).should == true
      end
      
      it 'has the test_component root method' do
        expect(@parent.test_component).to be_a(ComponentableSpec::TestComponent::TestComponent)
      end
      
      it 'the root method has _componentable_container available' do
        @parent.test_component.respond_to?(:_componentable_container).should == true
      end
      
      describe 'adding componentable_tests (stock :add method)' do
        [:test_component, :test_components, :add_test_component, :add_test_components].each do |method|
          it "adds the 'add methods' API: #{method}" do
            @parent.respond_to?(method).should == true
          end
        end
        
        it 'adds a component: test_component(name)' do
          added = @parent.test_component(:item1)
          expect(added).to be_a(Origen::Component::Default)
          expect(@parent.test_component._componentable_container[:item1]).to be_a(Origen::Component::Default)
        end
        
        it 'adds a component: test_components(name)' do
          added = @parent.test_components(:item2, class_name: ComponentableSpec::AddTest)
          expect(added).to be_a(ComponentableSpec::AddTest)
          expect(@parent.test_component._componentable_container[:item2]).to be_a(ComponentableSpec::AddTest)
        end
        
        it 'adds a component: add_test_component' do
          added = @parent.add_test_component(:item3)
          expect(added).to be_a(Origen::Component::Default)
          expect(@parent.test_component._componentable_container[:item3]).to be_a(Origen::Component::Default)
        end
        
        it 'adds a component: add_test_components' do
          added = @parent.add_test_components(:item4)
          expect(added).to be_a(Origen::Component::Default)
          expect(@parent.test_component._componentable_container[:item4]).to be_a(Origen::Component::Default)
        end
        
        it 'adds a component: test_component.add(name, ...)' do
          added = @parent.test_components(:item5)
          expect(added).to be_a(Origen::Component::Default)
          expect(@parent.test_component._componentable_container[:item5]).to be_a(Origen::Component::Default)
        end
        
        # Make sure that the block form correctly gets passed to all three methods to add a component
        
        it 'adds a component: test_component.add(name) do ...' do
          added = @parent.test_component(:item_block_1) do |c|
            c.test_block 'test'
          end
          expect(added.options).to include(:test_block)
          expect(added.options[:test_block]).to eql('test')
        end
        
        it 'adds a component: test_components.add(name) do ...' do
          added = @parent.test_component(:item_block_2) do |c|
            c.test_block_2 'test 2'
          end
          expect(added.options).to include(:test_block_2)
          expect(added.options[:test_block_2]).to eql('test 2')
        end
        
        it 'adds a component: add_test_component.add(name) do ...' do
          added = @parent.test_component(:item_block_3) do |c|
            c.class_name ComponentableSpec::AddTest
            c.test_block_3 'test 3'
          end
          expect(added.opts).to include(:test_block_3)
          expect(added.opts[:test_block_3]).to eql('test 3')
          expect(added).to be_a(ComponentableSpec::AddTest)
        end
        
        it 'complains if the component to add already exists' do
          expect { @parent.test_components(:item1) }.to raise_error Origen::Componentable::NameInUseError, /test_component name :item1 is already in use/
        end
        
        context "With dummy parent and includer classes" do
          it 'adds accessors back to the component name when COMPONENTABLE_ADDS_ACCESSORS = true' do
            parent = ComponentableSpec::ComponentableAccessorTestParents::Parent.new
            expect(parent.test_true._componentable_container).to_not include(:item1)
            parent.add_test_true(:item1)
            
            expect(parent.test_true._componentable_container).to include(:item1)
            expect(parent.test_true._componentable_container[:item1]).to be_a(Origen::Component::Default)
            expect(parent).to respond_to(:item1)
          end
          
          it 'does not add accessors back to the component name when COMPONENTABLE_ADDS_ACCESSORS = false' do
            parent = ComponentableSpec::ComponentableAccessorTestParents::Parent.new
            expect(parent.test_false._componentable_container).to_not include(:item1)
            parent.add_test_falses(:item1)
            
            expect(parent.test_false._componentable_container).to include(:item1)
            expect(parent.test_false._componentable_container[:item1]).to be_a(Origen::Component::Default)
            expect(parent).to_not respond_to(:item1)
          end
          
          it 'does not add accessors back to the component name by default' do
            parent = ComponentableSpec::ComponentableAccessorTestParents::Parent.new
            expect(parent.test_default._componentable_container).to_not include(:item1)
            parent.add_test_default(:item1)
            
            expect(parent.test_default._componentable_container).to include(:item1)
            expect(parent.test_default._componentable_container[:item1]).to be_a(Origen::Component::Default)
            expect(parent).to_not respond_to(:item1)
          end
          
          it 'does not add accessor methods when COMPONENTABLE_ADDS_ACCESSORS = true if :disable_accessors has been set' do
            parent = ComponentableSpec::ComponentableAccessorTestParents::ParentDisableAccessorsReader.new
            expect(parent.test_true._componentable_container).to_not include(:item1)
            parent.add_test_true(:item1)
            
            expect(parent.test_true._componentable_container).to include(:item1)
            expect(parent.test_true._componentable_container[:item1]).to be_a(Origen::Component::Default)
            expect(parent).to_not respond_to(:item1)
          end
          
          it 'will add accessors when COMPONENTABLE_ADDS_ACCESSORS = true and :disable_componentable_accessors is not set, but cease adding them if disable_accessors becomes set' do
            parent = ComponentableSpec::ComponentableAccessorTestParents::Parent.new
            expect(parent.test_true._componentable_container).to_not include(:item1)
            parent.add_test_true(:item1)
            expect(parent).to respond_to(:item1)
            
            parent.define_singleton_method(:disable_componentable_accessors) { true }
            parent.add_test_true(:item2)
            expect(parent).to_not respond_to(:item2)          
          end
          
          it 'will add accessors depending on the result of the parent :disable_componentable_accessors method' do
            parent = ComponentableSpec::ComponentableAccessorTestParents::ParentDisableAccessorsMethod.new
            expect(parent.test_true._componentable_container).to_not include(:item1)
            parent.add_test_true(:item1)
            
            expect(parent.test_true._componentable_container).to include(:item1)
            expect(parent.test_true._componentable_container[:item1]).to be_a(Origen::Component::Default)
            expect(parent).to_not respond_to(:item1)
            
            parent.add_test_component(:item1)
            expect(parent.test_component._componentable_container).to include(:item1)
            expect(parent.test_component._componentable_container[:item1]).to be_a(Origen::Component::Default)
            expect(parent).to respond_to(:item1)
          end
          
          it 'complains if a method Componentable is trying to add alredy exist' do
            expect do
              parent = ComponentableSpec::ComponentableAccessorTestParents::Parent.new
              parent.add_test_true(:item1)
              parent.add_test_component(:item1)
            end.to output(
              /Componentable: test_component is trying to add an accessor for item :item1 to parent ComponentableSpec::ComponentableAccessorTestParents::Parent but that method already exist! No accessor will be added./
            ).to_stdout_from_any_process
          end
          
        end
      end
     
      describe 'listing and getting test_components' do
        [:list_test_components, :test_components].each do |method|
          it "adds the listing/getting API: #{method}" do
            @parent.respond_to?(method).should == true
          end
        end
        
        it 'gets a listing of component names: list_componentable_tests' do
          @parent.list_test_components.should == @parent.test_component._componentable_container.keys
        end
        
        it 'gets a the test component hash: test_components()' do
          expect(@parent.test_components).to eql @parent.test_component._componentable_container
        end
        
        it 'can get an individual test component using: test_components[name]' do
          expect(@parent.test_components[:item1]).to be_a Origen::Component::Default
        end
        
        it 'gets a listing of component names: componentable_test.list' do
          @parent.test_component.list.should == @parent.test_component._componentable_container.keys
        end
      end
      
      describe 'querying for item existance' do
        [:has_test_component?, :test_component?].each do |method|
          it 'adds the querying for item existance API: #{method}' do
            expect(@parent).to respond_to(method)
          end
        end
        
        it 'can query for a particular item\'s existance: test_component?' do
          expect(@parent.test_component?(:item1)).to eql(true)
        end
        
        it 'has :has_test_component aliased to :test_component?' do
          expect(@parent.method(:has_test_component?)).to eql(@parent.method(:test_component?))
        end
      end
      
      describe 'querying instances' do
        [:test_components_of_class, :test_components_instances_of, :test_components_of_type].each do |method|
          it 'adds the querying instances API: #{method}' do
            expect(@parent).to respond_to(method)
          end
        end
        
        it 'can query for class types: test_component_instances_of' do
          @parent.test_components_of_class(Origen::Component::Default).should == ["item1", "item3", "item4", "item5", "item_block_1", "item_block_2"]
        end
        
        it 'can query for class types: test_components.instances_of' do
          @parent.test_components_instances_of(ComponentableSpec::AddTest).should == ["item2", "item_block_3"]
        end
        
        it 'has :test_components_of_class aliased to :test_components_of_type' do
          expect(@parent.method(:test_components_of_class)).to eql(@parent.method(:test_components_of_type))
        end
      end

      describe ':each and :select methods' do
        [:each_test_component, :all_test_components, :test_components,
         :select_test_components, :select_test_component
        ].each do |method|
          it "Adds the :each and :select API: #{method}" do
            expect(@parent).to respond_to(method)
          end
        end
        
        it 'iterates through test components: each_test_component' do
          h = Hash.new
          @parent.each_test_component do |name, instance|
            h[name] = instance
          end
          expect(h).to eql(@parent.test_component._componentable_container)
        end
        
        it 'has method :all_test_components aliased to method :each_test_component' do
          expect(@parent.method(:all_test_components)).to eql(@parent.method(:each_test_component))
        end
        
        it 'iterates through test components: test_components (with block)' do
          h = Hash.new
          @parent.test_components do |name, instance|
            h[name] = instance
          end
          expect(h).to eql(@parent.test_component._componentable_container)
        end
        
        it 'selects test components: select_test_components' do
          actual = @parent.test_component._componentable_container.select do |name, instance|
            name =~ /4/ || name =~ /5/
          end
          expected = @parent.select_test_components do |name, instance|
            name =~ /4/ || name =~ /5/
          end
          expect(expected).to eql(actual)
        end
        
        it 'has method :select_test_component aliased to method :select_test_components' do
          expect(@parent.method(:select_test_component)).to eql(@parent.method(:select_test_components))
        end
      end

      describe 'copying instances' do
        [:copy_test_component, :copy_test_components].each do |method|
          it "adds the API for copying instances: #{method}" do
            expect(@parent).to respond_to(method)
          end
        end
        
        it 'can copy an instance from one name to another: copy_test_component' do
          expect(@parent.test_component._componentable_container.key?(:item1)).to eql(true)
          expect(@parent.test_component._componentable_container.key?(:item1_copied)).to eql(false)
          obj_id = @parent.test_component._componentable_container[:item1].object_id
          
          @parent.copy_test_component(:item1, :item1_copied)
          
          expect(@parent.test_component._componentable_container.key?(:item1)).to eql(true)
          expect(@parent.test_component._componentable_container.key?(:item1_copied)).to eql(true)
          
          # This hsould be a deep copy
          expect(@parent.test_component._componentable_container[:item1_copied].object_id).to_not eql(obj_id)
        end
        
        it 'has method :copy_test_components aliased to method :copy_test_component' do
          expect(@parent.method(:copy_test_components)).to eql(@parent.method(:copy_test_component))
        end
      end

      describe 'moving instances' do
        [:move_test_component, :move_test_components].each do |method|
          it "adds the API for moving instances: #{method}" do
            expect(@parent).to respond_to(method)
          end
        end
        
        it 'can move an instance from one name to another: move_test_component' do
          expect(@parent.test_component._componentable_container.key?(:item1_copied)).to eql(true)
          expect(@parent.test_component._componentable_container.key?(:item1_moved)).to eql(false)
          obj_id = @parent.test_component._componentable_container[:item1_copied].object_id
          
          @parent.move_test_component(:item1_copied, :item1_moved)
          
          expect(@parent.test_component._componentable_container.key?(:item1_copied)).to eql(false)
          expect(@parent.test_component._componentable_container.key?(:item1_moved)).to eql(true)
          expect(@parent.test_component._componentable_container[:item1_moved].object_id).to eql(obj_id)
        end
        
        it 'has method :move_test_components aliased to method :move_test_component' do
          expect(@parent.method(:move_test_components)).to eql(@parent.method(:move_test_component))
        end
      end
      
      describe 'deleting instances' do
        [:delete_test_component, :delete_test_components, :remove_test_component, :remove_test_components,
         :delete_test_component!, :delete_test_components!, :remove_test_component!, :remove_test_components!,
        ].each do |method|
          it "adds the API for deleting instances: #{method}" do
            expect(@parent).to respond_to(method)
          end
        end
        
        it 'deletes an instance: delete_test_component' do
          expect(@parent.test_component._componentable_container.key?(:item1_moved)).to eql(true)
          expect(@parent.delete_test_component(:item1_moved)).to be_a(Origen::Component::Default)
          expect(@parent.test_component._componentable_container.key?(:item1_moved)).to eql(false)
        end
        
        it 'also deletes the accessor' do
          expect(@parent.test_component._componentable_container.key?(:item_block_3)).to eql(true)
          expect(@parent).to respond_to(:item_block_3)
          @parent.delete_test_component(:item_block_3)
          
          expect(@parent.test_component._componentable_container.key?(:item_block_3)).to eql(false)
          expect(@parent).to_not respond_to(:item_block_3)
        end
        
        it "detects if the 'accessor' is not actually an accessor but another method and does not delete it" do
          parent = ComponentableSpec::ComponentableAccessorTestParents::ParentDisableAccessorsReader.new
          parent.add_test_component(:test_add)
          expect(parent.test_component._componentable_container).to have_key(:test_add)
          
          parent.delete_test_component(:test_add)
          expect(parent.test_component._componentable_container).to_not have_key(:test_add)
          expect(parent).to respond_to(:test_add)
          expect(parent.test_add).to eql('Hi!')
        end
        
        it 'complains if the instance name is not found: delete_test_component' do
          expect {@parent.delete_test_component(:item1_moved)}.to raise_error(Origen::Componentable::NameDoesNotExistError)
        end
        
        it 'has method :delete_test_components aliased to method :delete_test_component' do
          expect(@parent.method(:delete_test_components)).to eql(@parent.method(:delete_test_component))
        end

        it 'has method :remove_test_component aliased to method :delete_test_component' do
          expect(@parent.method(:remove_test_component)).to eql(@parent.method(:delete_test_component))
        end
        
        it 'has method :remove_test_components aliased to method :delete_test_component' do
          expect(@parent.method(:remove_test_components)).to eql(@parent.method(:delete_test_component))
        end

        it 'deletes an instance or returns nil if the instance name is not found: delete_test_component!' do
          expect(@parent.test_component._componentable_container.key?(:item1_moved)).to eql(false)
          expect(@parent.delete_test_component!(:item1_moved)).to eql(nil)
        end
        
        it 'has method :delete_test_components! aliased to method :delete_test_component!' do
          expect(@parent.method(:delete_test_components!)).to eql(@parent.method(:delete_test_component!))
        end

        it 'has method :remove_test_component! aliased to method :delete_test_component!' do
          expect(@parent.method(:remove_test_component!)).to eql(@parent.method(:delete_test_component!))
        end
        
        it 'has method :remove_test_components! aliased to method :delete_test_component!' do
          expect(@parent.method(:remove_test_components!)).to eql(@parent.method(:delete_test_component!))
        end
      end
      
      describe 'deleting all instances' do
        [:delete_all_test_components, :clear_test_components, :remove_all_test_components].each do |method|
          it "adds the API for deleting all instances: #{method}" do
            expect(@parent).to respond_to(method)
          end
        end
        
        it 'deletes all accessors its added on the parent' do
          parent = ComponentableSpec::ComponentableAccessorTestParents::Parent.new
          expect(parent).to_not respond_to(:item1)
          expect(parent).to_not respond_to(:item2)
          expect(parent).to_not respond_to(:item3)
          
          parent.add_test_component(:item1)
          parent.add_test_component(:item2)
          parent.add_test_component(:item3)
          
          expect(parent).to respond_to(:item1)
          expect(parent).to respond_to(:item2)
          expect(parent).to respond_to(:item3)
          
          parent.clear_test_components
          
          expect(parent).to_not respond_to(:item1)
          expect(parent).to_not respond_to(:item2)
          expect(parent).to_not respond_to(:item3)
        end
        
        it 'deletes all the test components: delete_all_test_compoments' do
          expect(@parent.test_component._componentable_container).to_not eql({})
          @parent.delete_all_test_components
          expect(@parent.test_component._componentable_container).to eql({})
        end
        
        it 'has method :clear_test_components aliased to method :delete_all_test_component' do
          expect(@parent.method(:clear_test_components)).to eql(@parent.method(:delete_all_test_components))
        end
        
        it 'has method :remove_all_test_components aliased to method :delete_all_test_component' do
          expect(@parent.method(:remove_all_test_components)).to eql(@parent.method(:delete_all_test_components))
        end
      end
    end
  
  end
end
