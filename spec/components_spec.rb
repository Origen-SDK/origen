# Note that components is just blank inclusion of the Origen::Componentable API, which is thoroughly
# spec-ed in spec/componentable
# This is just for a bit of extra reassurance and to flag any issues that may arise if the model
# initializer or the naming template are changed.

module ComponentsSpec
  class ComponentsTest
    include Origen::Model
  end
end

fdescribe 'Components Spec' do
  context 'with dummy class including Origen::Model' do
    before :context do
      @test = ComponentsSpec::ComponentsTest.new
    end

    it 'is available automatically when Origen::Model is included' do
      expect(@test).to respond_to(:component)
      expect(@test.component._componentable_container).to eql({})
    end
  
    # Can only do a subset of the most used ones. There's an entire spec dedicated to this.
    [:components, :add_component, :has_component?, :list_components, :delete_all_components].each do |method|
      it "gives its parent class the componentable API: #{method}" do
        expect(@test).to respond_to(method)
      end
    end
  
    # Just do some really simple tests. Basically a read/write test.    
    it 'can add components' do
      @test.components(:item1)
      @test.components(:item2)
      
      expect(@test.component._componentable_container).to have_key(:item1)
      expect(@test.component._componentable_container).to have_key(:item2)
    end
    
    it 'complains if the component to add already exists' do
      expect { @test.component(:item1) }.to raise_error Origen::Componentable::NameInUseError, /component name :item1 is already in use/
    end
    
    it 'can query component existance' do
      expect(@test.has_component?(:item1)).to be true
      expect(@test.has_component?(:item2)).to be true
      expect(@test.has_component?(:item3)).to be false
    end
    
    it 'can list components' do
      expect(@test.list_components).to eql ["item1", "item2"]
    end
    
    it 'can delete all components' do
      @test.delete_all_components
      expect(@test.list_components).to eql([])
      expect(@test.component._componentable_container).to eql({})
    end
    
  end
end
