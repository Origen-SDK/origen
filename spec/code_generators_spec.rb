require "spec_helper"
require 'open3'

describe "code generators (origen new command)" do
  before :all do
    @app_dir = Origen.root.join('app')
    @generated_files = []
    FileUtils.rm_rf(@app_dir) if @app_dir.exist?
  end

  before :each do
    reload!
  end

  after :each do
    Origen.app.unload_target!
  end

  # Comment this out if you need to inspect the created files for debug
  after :all do
    FileUtils.rm_rf(@app_dir) if @app_dir.exist?
    @generated_files.each do |f|
      FileUtils.rm_rf(f) if File.exist?(f)
    end
  end

  def reload!
    Origen::Loader.unload
  end

  def load_falcon
    reload!
    Origen.target.temporary = -> { Origen::DUT::Falcon.new }
    Origen.target.load!
  end

  # Like system for executing the 'origen new ...' command, but any arguments will be supplied as
  # user input and a fail will and it is run in the current process rather than invoking an external
  # one so that test coverage is picked up.
  def system!(cmd, *command_line_inputs)
    command_line_inputs.each do |input|
      expect(Thor::LineEditor).to receive(:readline).and_return(input)
    end
    cmd = cmd.strip.sub('origen new ', '')
    args = cmd.split(/\s+/)
    name = args.shift
    Origen::CodeGenerators.invoke name, args
  end
  
  it "can generate a DUT block" do
    @generated_files << Origen.root.join('target', 'falcon.rb')
    system! 'origen new dut falcon'

    load_falcon
    dut.is_a?(Origen::DUT::Falcon).should == true
  end

  it "can generate a DUT within a family" do
    @generated_files << Origen.root.join('target', 'first.rb')
    system! 'origen new dut family/first'

    reload!
    Origen.target.temporary = -> { Origen::DUT::Family::First.new }
    Origen.target.load!

    dut.is_a?(Origen::DUT::Family::First).should == true
  end

  it 'can generate a sub-block' do
    system! 'origen new block nvm/flash2k', ' '
    nvm = Origen::NVM::Flash2k.new
    nvm.is_a_model_and_controller?.should == true
  end

  it 'can generate a sub-block and add it to the DUT' do
    system! 'origen new block nvm/flash4k', '1'
    load_falcon

    dut.nvm.is_a?(Origen::NVM::Flash4k).should == true
  end

  it 'can add a module to a DUT model' do
    # Grab the command to add a module to the Falcon model from the user advice within the
    # model file to test that it works
    f = Origen.root.join('app', 'blocks', 'dut', 'derivatives', 'falcon', 'model.rb')
    cmd = f.open.find { |line| line =~ /origen new module/ }.gsub('#', '').strip

    system! cmd

    # add a method to the new module so that we can test it
    f = Origen.root.join('app', 'blocks', 'dut', 'derivatives', 'falcon', 'model', 'my_module_name.rb')
    f.write(f.read.gsub('# def my_method', "def yo; 'yo!'; end\n"))

    load_falcon
    dut.yo.should == 'yo!'
  end

  it 'can add a module to a DUT controller' do
    # Grab the command to add a module to the Falcon model from the user advice within the
    # model file to test that it works
    f1 = Origen.root.join('app', 'blocks', 'dut', 'derivatives', 'falcon', 'controller.rb')
    cmd = f1.open.find { |line| line =~ /origen new module/ }.gsub('#', '').strip

    system! cmd

    # Add a method to the new module so that we can test it
    f = Origen.root.join('app', 'blocks', 'dut', 'derivatives', 'falcon', 'controller', 'my_module_name.rb')
    f.write(f.read.gsub('# def my_method', "def yo_from_c; 'yo!'; end\n"))

    load_falcon
    dut.yo_from_c.should == 'yo!'
  end

  it 'can create a feature' do
    module Origen
      class PartTest
        include Origen::Model
      end
    end

    system! 'origen new feature my_feature'

    # Uncomment the examples from the parameter file so that we can test it
    f = Origen.root.join('app', 'blocks', 'my_feature', 'parameters.rb')
    f.write(f.read.gsub(/^# (\s*(params|define_params|end))/, '\1'))

    model = Origen::PartTest.new
    model.load_block('my_feature').should == true
    model.params.tprog.should == 20.uS
  end

  it 'can create a model without a controller' do
    system! 'origen new model my_cg_model', 'n'

    model = Origen::MyCgModel.new
    model.is_an_origen_model?.should == true
    model.is_a_model_and_controller?.should == false
  end

  it 'can create a model with a controller' do
    system! 'origen new model my_cg_model', 'y'

    model = Origen::MyCgModel.new
    model.is_an_origen_model?.should == true
    model.is_a_model_and_controller?.should == true
  end

  it 'can create add a module to a model' do
    system! 'origen new module app/lib/origen/my_cg_model.rb my_module'

    # add a method to the new module so that we can test it
    f = Origen.root.join('app', 'lib', 'origen', 'my_cg_model', 'my_module.rb')
    f.write(f.read.gsub('# def my_method', "def yo; 'yo!'; end\n"))
    reload!

    model = Origen::MyCgModel.new
    model.yo.should == 'yo!'
  end

  it 'can create a class' do
    system! 'origen new class my_class'

    model = Origen::MyClass.new
    model.try(:is_an_origen_model?).should == nil
  end

  it 'can create add a module to a class' do
    system! 'origen new module app/lib/origen/my_class.rb my_module'

    # add a method to the new module so that we can test it
    f = Origen.root.join('app', 'lib', 'origen', 'my_class', 'my_module.rb')
    f.write(f.read.gsub('# def my_method', "def yo; 'yo!'; end\n"))
    reload!

    model = Origen::MyClass.new
    model.yo.should == 'yo!'
  end

  describe "nested sub_blocks" do
    it "can be added to a derivative block" do
      # Grab the command to add a module to the Falcon model from the user advice within the
      # model file to test that it works
      f1 = Origen.root.join('app', 'blocks', 'dut', 'derivatives', 'falcon', 'sub_blocks.rb')
      cmd = f1.open.find { |line| line =~ /origen new block app/ }.gsub('#', '').sub('my_sub_block_name', 'derivative_sub_block').strip

      system! cmd

      load_falcon
      dut.derivative_sub_block.should be
      dut.derivative_sub_block.is_a?(Origen::DUT::Falcon::DerivativeSubBlock).should == true
      dut.derivative_sub_block.is_a_model_and_controller?.should == true
    end

    it "can be added to a parent block" do
      f1 = Origen.root.join('app', 'blocks', 'dut', 'sub_blocks.rb')
      cmd = f1.open.find { |line| line =~ /origen new block app/ }.gsub('#', '').sub('my_sub_block_name', 'parent_sub_block').strip

      system! cmd

      load_falcon
      dut.parent_sub_block.should be
      dut.parent_sub_block.is_a?(Origen::DUT::Falcon::ParentSubBlock).should == true
      dut.parent_sub_block.is_a_model_and_controller?.should == true
    end

    it "attributes can be added to sub-blocks" do
      f = Origen.root.join('app', 'blocks', 'dut', 'sub_blocks', 'parent_sub_block', 'attributes.rb')
      f.write(f.read.gsub('# @has_feature_x', "@has_feature_x"))

      load_falcon

      dut.parent_sub_block.has_feature_x?.should == true

      f = Origen.root.join('app', 'blocks', 'dut', 'derivatives', 'falcon', 'sub_blocks', 'derivative_sub_block', 'attributes.rb')
      f.write(f.read.gsub('# @has_feature_x', "@has_feature_y"))

      load_falcon

      dut.parent_sub_block.has_feature_x?.should == true
      dut.derivative_sub_block.has_feature_y?.should == true
    end

    it "registers can be added to sub-blocks" do
      f = Origen.root.join('app', 'blocks', 'dut', 'sub_blocks', 'parent_sub_block', 'registers.rb')
      f.write(f.read.gsub('# Example', "add_reg :reg1, 0x1000 # Example"))

      load_falcon

      dut.parent_sub_block.reg1.address.should == 0x1000

      f = Origen.root.join('app', 'blocks', 'dut', 'derivatives', 'falcon', 'sub_blocks', 'derivative_sub_block', 'registers.rb')
      f.write(f.read.gsub('# Example', "add_reg :reg2, 0x2000 # Example"))

      load_falcon

      dut.parent_sub_block.reg1.address.should == 0x1000
      dut.derivative_sub_block.reg2.address.should == 0x2000
    end

    it "sub-blocks can be added to sub-blocks" do
      f1 = Origen.root.join('app', 'blocks', 'dut', 'derivatives', 'falcon', 'sub_blocks', 'derivative_sub_block', 'sub_blocks.rb')
      cmd = f1.open.find { |line| line =~ /origen new block app/ }.gsub('#', '').sub('my_sub_block_name', 'block1').strip

      system! cmd

      load_falcon
      dut.derivative_sub_block.block1.should be
      dut.derivative_sub_block.block1.is_a?(Origen::DUT::Falcon::DerivativeSubBlock::Block1).should == true
      dut.derivative_sub_block.block1.is_a_model_and_controller?.should == true

      # Quickly test adding a register to make sure the loading of the files works OK
      f = Origen.root.join('app', 'blocks', 'dut', 'derivatives', 'falcon', 'sub_blocks', 'derivative_sub_block', 'sub_blocks', 'block1', 'registers.rb')
      f.write(f.read.gsub('# Example', "add_reg :reg3, 0x3000 # Example"))

      load_falcon

      dut.derivative_sub_block.block1.reg3.address.should == 0x3000
      dut.derivative_sub_block.block1.has_reg?(:reg1).should == false
      dut.derivative_sub_block.block1.has_reg?(:reg2).should == false
    end
  end
end
