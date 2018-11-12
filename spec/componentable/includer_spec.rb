RSpec.shared_examples :componentable_includer_spec do
  module ComponentableSpec
  end
  
  describe 'Includer API Spec' do
    context 'testing with a dummy class' do
      before :context do
        # Create a dummy class to use as the includer
        @includer_class = Class.new do
          # Since we are making this class anonyomously, need to manually assign a name
          # if we do: ComponentableName = "APITester"
          # For some reason this adds it globally... not sure what that's about. So have to use const_set for this.
          self.const_set(:COMPONENTABLE_SINGLETON_NAME, "api_tester")
          
          include Origen::Model
          include Origen::Componentable
        end
        
        # Instantiate the dummy class now. Assume that we are going though the Origen::Model initializer
        @includer = @includer_class.new
        
        # Make sure that we can access the compentable container instance variable.
        # If this doesn't work everything below will fail anyway, so may as well do it here before proceeding
        @includer.instance_variable_defined?(:@_componentable_container).should == true
        @includer.instance_variable_get(:@_componentable_container).should == {}
        
        @includer.respond_to?(:_componentable_container).should == true
        @includer._componentable_container.should == {}
      end
      
      it 'can set its parent' do
        expect(@includer.parent).to be(nil)
        
        temp_parent = ComponentableSpec::InitTests::ParentNoModel.new
        @includer.parent = temp_parent
        expect(@includer.parent).to be_a(ComponentableSpec::InitTests::ParentNoModel)
      end
      
      describe 'Componentable method: add (stock :add method)' do
        it 'Adds a componentable item to its container (by class object)' do
          @includer.add(:test_string_by_class, class_name: ComponentableSpec::AddTest)
          
          @includer._componentable_container.keys.should == ["test_string_by_class"]
          @includer._componentable_container[:test_string_by_class].class.should == ComponentableSpec::AddTest
        end
        
        it 'Adds a componentable item to its container (by name of class as String)' do
          @includer.add(:test_object_by_string, class_name: 'ComponentableSpec::AddTest')
          
          @includer._componentable_container.keys.should == ["test_string_by_class", "test_object_by_string"]
          @includer._componentable_container[:test_string_by_class].class.should == ComponentableSpec::AddTest
        end
        
        it 'Adds a componentable item to its container (no classname, instantiates Origen::Component::Default Object)' do
          @includer.add(:test_default)
          
          @includer._componentable_container.has_key?('test_default').should == true
          @includer._componentable_container[:test_default].class.should == Origen::Component::Default
        end
        
        it 'Instantiates the given class and passes all options through' do
          @includer.add(:default, class_name: 'ComponentableSpec::AddTest', option1: 'option1', option2: 'options2')
          
          @includer._componentable_container.has_key?(:default).should == true
          @includer._componentable_container[:default].class.should == ComponentableSpec::AddTest
          
          expect(@includer._componentable_container[:default].opts[:option1]).to eql('option1')
          expect(@includer._componentable_container[:default].opts[:option2]).to eql('options2')
        end
        
        it 'Complains if the name of the component already exists' do
          expect {@includer.add(:default)}.to raise_error Origen::Componentable::NameInUseError, /api_tester name :default is already in use/
        end

        it 'Complains if the given class name cannot be found (given as a String)' do
          expect {@includer.add(:test_unknown, class_name: "UnknownClass")}.to raise_error Origen::Componentable::NameDoesNotExistError, /class_name option 'UnknownClass' cannot be found/
        end
        
        context "with multiple instances" do
          before :context do
            @multiple_includer = @includer_class.new
          end
          
          it 'can add multiple instances at a time' do
            @multiple_includer.add(:test, instances: 3)
            expect(@multiple_includer._componentable_container.keys.size).to eql(3)
            expect(@multiple_includer._componentable_container).to have_key('test0')
            expect(@multiple_includer._componentable_container).to have_key('test1')
            expect(@multiple_includer._componentable_container).to have_key('test2')
          end
          
          it 'passes all the options to each instance if it is not an array' do
            @multiple_includer.add(:test_opt, instances: 3, class_name: 'ComponentableSpec::AddTest', option: 'option')
            
            expect(@multiple_includer._componentable_container).to have_key('test_opt0')
            expect(@multiple_includer._componentable_container).to have_key('test_opt1')
            expect(@multiple_includer._componentable_container).to have_key('test_opt2')
            
            expect(@multiple_includer._componentable_container[:test_opt0].opts[:option]).to eql('option')
            expect(@multiple_includer._componentable_container[:test_opt1].opts[:option]).to eql('option')
            expect(@multiple_includer._componentable_container[:test_opt2].opts[:option]).to eql('option')
          end
          
          it 'splits the options evenly for each option' do
            @multiple_includer.add(:test_opt_ind, instances: 3, class_name: 'ComponentableSpec::AddTest', 
                                   option: ['option_A', 'option_B', 'option_C'],
                                   parameter: ['param_A', 'param_B', 'param_C'])

            expect(@multiple_includer._componentable_container).to have_key('test_opt_ind0')
            expect(@multiple_includer._componentable_container).to have_key('test_opt_ind1')
            expect(@multiple_includer._componentable_container).to have_key('test_opt_ind2')
            
            expect(@multiple_includer._componentable_container[:test_opt_ind0].opts[:option]).to eql('option_A')
            expect(@multiple_includer._componentable_container[:test_opt_ind1].opts[:option]).to eql('option_B')
            expect(@multiple_includer._componentable_container[:test_opt_ind2].opts[:option]).to eql('option_C')
            
            expect(@multiple_includer._componentable_container[:test_opt_ind0].opts[:parameter]).to eql('param_A')
            expect(@multiple_includer._componentable_container[:test_opt_ind1].opts[:parameter]).to eql('param_B')
            expect(@multiple_includer._componentable_container[:test_opt_ind2].opts[:parameter]).to eql('param_C')
          end
          
          it 'complains if an uneven option array is given' do
            expect {
              @multiple_includer.add(:test_error, instances: 3, class_name: 'ComponentableSpec::AddTest', 
                                   option: ['option_A', 'option_B'])
            }.to raise_error Origen::Componentable::Error, 
              'Error when adding test_error: size of given option :option (2) does not match the number of instances specified (3)'
          end
          
          it 'can correctly handle the corner case of using arrays' do
            @multiple_includer.add(:test_corner_case, instances: 3, class_name: 'ComponentableSpec::AddTest', 
                                   option: ['option_A', 'option_B', 'option_C'],
                                   parameter: [['param_A', 'param_B']])
            
            expect(@multiple_includer._componentable_container).to have_key('test_corner_case0')
            expect(@multiple_includer._componentable_container).to have_key('test_corner_case1')
            expect(@multiple_includer._componentable_container).to have_key('test_corner_case2')
            
            expect(@multiple_includer._componentable_container[:test_corner_case0].opts[:option]).to eql('option_A')
            expect(@multiple_includer._componentable_container[:test_corner_case1].opts[:option]).to eql('option_B')
            expect(@multiple_includer._componentable_container[:test_corner_case2].opts[:option]).to eql('option_C')
            
            expect(@multiple_includer._componentable_container[:test_corner_case0].opts[:parameter]).to eql(['param_A', 'param_B'])
            expect(@multiple_includer._componentable_container[:test_corner_case1].opts[:parameter]).to eql(['param_A', 'param_B'])
            expect(@multiple_includer._componentable_container[:test_corner_case2].opts[:parameter]).to eql(['param_A', 'param_B'])
          end
        end
      end
      
      describe 'Componentable method: list' do
        it 'list the names of all the added objects' do
          @includer.list.should == [
            "test_string_by_class",
            "test_object_by_string",
            "test_default",
            "default"
          ]
        end
        
        it 'returns an empty array if there are no items present' do
          includer = @includer_class.new
          includer.list.should == []
        end
      end
      
      describe 'Iterating through the componentable container' do
        it 'has an each method' do
          @includer.respond_to?(:each).should == true
        end
        
        it 'can iterate through the names and corresponding objects' do
          # Since the guts of all this is just a hash, really we just want to make sure
          # that @includer.each == @includer._componentable_container.each
          # So, we'll just make a new hash using the @includer.each method. If we iterate though
          # all the key/value pairs correctly, we'll just end up with the same hash as the componentable_container
          
          includer_each = Hash.new
          @includer.each do |name, obj|
            includer_each[name] = obj
          end
          
          includer_each.should == @includer._componentable_container
        end
      end
      
      describe 'Componentable method: has?' do
        it 'returns true if :name has been added' do
          @includer.has?(:default).should == true
        end
        
        it 'returns false if :name has not been added' do
          @includer.has?(:unknown).should == false
        end
      end

      describe 'Componentable method: instances_of' do
        it 'returns all of the component\'s names that are of class :klass where :klass is a class object' do
          @includer.instances_of(ComponentableSpec::AddTest).should == [
            "test_string_by_class",
            "test_object_by_string",
            "default"
          ]
          
          @includer.instances_of(Origen::Component::Default).should == ["test_default"]
        end
        
        it 'returns all of the component\'s names that are of class :klass where :klass is an instance of the class to search for' do
          @includer.instances_of(@includer._componentable_container[:default]).should == [
            "test_string_by_class",
            "test_object_by_string",
            "default"
          ]
        end
        
        it 'returns an empty array if no components match' do
          @includer.instances_of(String).should == []
          @includer.instances_of("test").should == []
        end
      end

      describe 'Componentable method: copy' do
        it 'copies component :name to component :name. Default is a deep copy (objects are NOT the same)' do
          @includer._componentable_container.key?(:default_copy).should == false
          @includer.copy(:default, :default_copy)
          
          @includer._componentable_container.key?(:default_copy).should == true
          @includer._componentable_container[:default_copy].class.should == ComponentableSpec::AddTest
          @includer._componentable_container[:default_copy].object_id.should_not == @includer._componentable_container[:default].object_id
        end
        
        it 'copies component :name to component :new_name, with option deep_copy: true' do
          @includer._componentable_container.key?(:default_deep_copy).should == false
          @includer.copy(:default, :default_deep_copy, deep_copy: true)
          
          @includer._componentable_container.key?(:default_deep_copy).should == true
          @includer._componentable_container[:default_deep_copy].class.should == ComponentableSpec::AddTest
          @includer._componentable_container[:default_deep_copy].object_id.should_not == @includer._componentable_container[:default].object_id
        end
        
        it 'copies component :name to component :new_name, with option deep_copy: false' do
          @includer._componentable_container.key?(:default_shallow_copy).should == false
          @includer.copy(:default, :default_shallow_copy, deep_copy: false)
          
          @includer._componentable_container.key?(:default_shallow_copy).should == true
          @includer._componentable_container[:default_shallow_copy].class.should == ComponentableSpec::AddTest
          @includer._componentable_container[:default_shallow_copy].object_id.should == @includer._componentable_container[:default].object_id
          @includer._componentable_container[:default_shallow_copy].object_id.should_not == @includer._componentable_container[:default_deep_copy].object_id
         end
        
        it 'complains if :name does not exist' do
          expect {@includer.copy(:no_name, :default_deep_copy_2)}.to raise_error Origen::Componentable::NameDoesNotExistError, /api_tester name :no_name does not exist/
        end
        
        it 'complains if :new_name does exist and :overwrite is not set (default)' do
          expect {@includer.copy(:default, :default_deep_copy)}.to raise_error Origen::Componentable::NameInUseError, /api_tester name :default_deep_copy is already in use/
        end
        
        it 'copies the component :name to :new_name, overwriting what is at :new_name, if :override is set' do
          @includer._componentable_container.key?(:default_copy).should == true
          old_object = @includer._componentable_container[:default_copy].object_id
          
          @includer.copy(:default, :default_copy, overwrite: true)
        end
      end
      
      describe 'Componentable method: move' do
        it 'moves component :name to component :new_name' do
          @includer._componentable_container.key?(:default_move).should == false
          @includer._componentable_container.key?(:default_copy).should == true
          old_id = @includer._componentable_container[:default_copy].object_id
          @includer.move(:default_copy, :default_move)
          
          @includer._componentable_container.key?(:default_move).should == true
          @includer._componentable_container.key?(:default_copy).should == false
          @includer._componentable_container[:default_move].class.should == ComponentableSpec::AddTest
          @includer._componentable_container[:default_move].object_id.should == old_id          
        end
        
        it 'complains if :name does not exist' do
          expect {@includer.move(:no_name, :default_move_2)}.to raise_error Origen::Componentable::NameDoesNotExistError, /api_tester name :no_name does not exist/
        end
        
        it 'complains if :new_name does exist and :overwrite is not set (default)' do
          expect {@includer.move(:default, :default_move)}.to raise_error Origen::Componentable::NameInUseError, /api_tester name :default_move is already in use/
        end
        
        it 'moves the component :name to :new_name, overwriting what is at :new_name, if :overwrite is set' do
          @includer._componentable_container.key?(:default_move).should == true
          @includer._componentable_container.key?(:default_deep_copy).should == true
          old_id = @includer._componentable_container[:default_deep_copy].object_id
          @includer.move(:default_deep_copy, :default_move, overwrite: true)

          @includer._componentable_container.key?(:default_move).should == true
          @includer._componentable_container.key?(:default_deep_copy).should == false
          @includer._componentable_container[:default_move].class.should == ComponentableSpec::AddTest
          @includer._componentable_container[:default_move].object_id.should == old_id
        end
      end
      
      describe 'Componentable method: delete' do
        it 'deletes the component :name' do
          @includer._componentable_container.should_not == {}
          @includer._componentable_container.key?(:default).should == true
          to_delete_object_id = @includer._componentable_container[:default].object_id
          deleted_object = @includer.delete(:default)
          
          deleted_object.class.should == ComponentableSpec::AddTest
          deleted_object.object_id.should == to_delete_object_id
          @includer._componentable_container.key?(:default).should == false
        end
        
        it 'complains if :name does not exist' do
          expect {@includer.delete(:no_name)}.to raise_error Origen::Componentable::NameDoesNotExistError, /api_tester name :no_name does not exist/
        end
        
        it 'has method :remove aliased to :delete' do
          expect(@includer.method(:remove)).to eql(@includer.method(:delete))
        end
      end
      
      describe 'Componentable method: delete!' do
        it 'also deletes the component :name' do
          @includer._componentable_container.should_not == {}
          @includer._componentable_container.key?(:default_move).should == true
          to_delete_object_id = @includer._componentable_container[:default_move].object_id
          deleted_object = @includer.delete!(:default_move)
          
          deleted_object.class.should == ComponentableSpec::AddTest
          @includer._componentable_container.key?(:default_move).should == false
        end
        
        it 'returns nil if the component :name does not exist (instead of complaining)' do
          @includer.delete!(:no_name).should == nil
        end
        
        it 'has method :remove! aliased to :delete!' do
          expect(@includer.method(:remove!)).to eql(@includer.method(:delete!))
        end
      end
      
      describe 'Componentable method: delete_all' do
        it 'deletes all components' do
          @includer._componentable_container.should_not == {}
          @includer.delete_all
          @includer._componentable_container.should == {}
        end
        
        it 'has method :remove_all aliased to :delete_all' do
          expect(@includer.method(:remove_all)).to eql(@includer.method(:delete_all))
        end
        
        it 'has method :clear aliased to :delete_all' do
          expect(@includer.method(:clear)).to eql(@includer.method(:delete_all))
        end
      end
    end

  end
end
