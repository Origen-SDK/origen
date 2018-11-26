require "spec_helper"
require 'open3'

describe "code generators (origen new command)" do
  before :all do
    @app_dir = Origen.root.join('app')
    @generated_files = []
    FileUtils.rm_rf(@app_dir) if @app_dir.exist?
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

  def load_falcon
    Origen::Loader.unload
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
  
  it "can generate a DUT part" do
    @generated_files << Origen.root.join('target', 'falcon.rb')
    system! 'origen new dut falcon'

    load_falcon
    dut.is_a?(Origen::DUT::Falcon).should == true
  end

  it 'can generate a sub-block' do
    system! 'origen new sub_block nvm/flash2k', ' '
    nvm = Origen::NVM::Flash2k.new
    nvm.is_a_model_and_controller?.should == true
  end

  it 'can generate a sub-block and add it to the DUT' do
    system! 'origen new sub_block nvm/flash4k', '1'
    load_falcon

    dut.nvm.is_a?(Origen::NVM::Flash4k).should == true
  end

  it 'can add a module to a DUT model' do
    # Grab the command to execute from the Falcon model user advice to test that it
    # actually works
    f = Origen.root.join('app', 'parts', 'dut', 'derivatives', 'falcon', 'model.rb')
    cmd = f.open.find { |line| line =~ /origen new module/ }.gsub('#', '').strip

    system! cmd

    # Add a method to the new module so that we can test it
    f = Origen.root.join('app', 'parts', 'dut', 'derivatives', 'falcon', 'model', 'my_module_name.rb')
    f.write(f.read.gsub('# def my_method', "def yo; 'yo!'; end\n"))

    load_falcon
    dut.yo.should == 'yo!'
  end

  it 'can add a module to a DUT controller' do
    # Grab the command to execute from the Falcon model user advice to test that it
    # actually works
    f1 = Origen.root.join('app', 'parts', 'dut', 'derivatives', 'falcon', 'controller.rb')
    cmd = f1.open.find { |line| line =~ /origen new module/ }.gsub('#', '').strip

    system! cmd

    # Add a method to the new module so that we can test it
    f = Origen.root.join('app', 'parts', 'dut', 'derivatives', 'falcon', 'controller', 'my_module_name.rb')
    f.write(f.read.gsub('# def my_method', "def yo_from_c; 'yo!'; end\n"))

    load_falcon
    dut.yo_from_c.should == 'yo!'
  end
end
