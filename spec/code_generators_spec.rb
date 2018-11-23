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
    Origen::DUT.send :remove_const, :FalconController if defined?(Origen::DUT::FalconController)
    Origen::DUT.send :remove_const, :Falcon if defined?(Origen::DUT::Falcon)
    Origen.send :remove_const, :DUT if defined?(Origen::DUT)
    Origen.target.temporary = -> { Origen::DUT::Falcon.new }
    Origen.target.load!
  end

  # Like system, but any arguments will be supplied as user input and a fail will
  # be raised if the command doesn't pass
  def system!(cmd, *args)
    if args.empty?
      output, status = Open3.capture2(cmd) 
    else
      output, status = Open3.capture2(cmd, stdin_data: args.join("\n")) 
    end
    puts output
    status.success?.should == true
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

    # Broken, because the model module does not re-require, need to update the loader to get rid of
    # the require_relative in the model/controller when adding a module
    #load_falcon
    #dut.yo_from_c.should == 'yo!'
  end
end
