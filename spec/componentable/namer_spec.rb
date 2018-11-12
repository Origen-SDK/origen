RSpec.shared_examples :componentable_namer_spec do

  module ComponentableSpec
    module NameTests
      class Tool; end
      class ToolSet; end
      class Toolset; end
      class High; end
      class Bus; end
      class Stress; end
      class Mesh; end
      class Bench; end
      class Analysis; end
      class Criterion; end
      class Box; end
      class Buzz; end
      
      class ToolCustomName
        COMPONENTABLE_PLURAL_NAME = 'Toolset'
      end
    end
  end

  describe 'Pluralization and Singleton Namer' do
    describe 'Method: Componentable.componentable_container_name' do
      it 'Pluralizes the name (Tool)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Tool.new)[:plural].should == :tools
      end

      it 'Pluralizes the name (ToolSet)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::ToolSet.new)[:plural].should == :tool_sets
      end

      it 'Pluralizes the name (Toolset)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Toolset.new)[:plural].should == :toolsets
      end

      it 'Pluralizes the name -h (High)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::High.new)[:plural].should == :highs
      end
      
      it 'Pluralizes irregular case -s (Bus)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Bus.new)[:plural].should == :buses
      end

      it 'Pluralizes irregular case -ss (Stree)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Stress.new)[:plural].should == :stresses
      end

      it 'Pluralizes irregular case -sh (Mesh)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Mesh.new)[:plural].should == :meshes
      end

      it 'Pluralizes irregular case -ch (bench)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Bench.new)[:plural].should == :benches
      end
      
      it 'Pluralizes irregular case -is (Analysis)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Analysis.new)[:plural].should == :analyses
      end
      
      it 'Pluralizes the irregular case -on (Criterion)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Criterion.new)[:plural].should == :criteria
      end

      it 'Pluralizes irregular case -x (Box)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Box.new)[:plural].should == :boxes
      end
      
      it 'Pluralizes irregular case -z (Buzz)' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::Buzz.new)[:plural].should == :buzzes
      end
      
      it 'Uses the includer class\'s ComponentableName class variable instead if it is set' do
        Origen::Componentable.componentable_names(ComponentableSpec::NameTests::ToolCustomName.new)[:plural].should == :toolset
      end
    end
  end
end
