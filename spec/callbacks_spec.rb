require "spec_helper"

class CallbacksSpecTopLevel
  include Origen::TopLevel

  def initialize
    $_load_count ||= 0
    $_load_count += 1
  end

  def startup(options={})
    $tester.set_timeset("nvmbist", 40)
    $_captured_callbacks << "toplevel:startup"
  end

  def shutdown(options={})
    $_captured_callbacks << "toplevel:shutdown"
  end
end

class CallbacksSpecTopLevelModel1
  include Origen::Model

  def initialize
    reg :r1, 0 do
      bits 31..0, :data
    end
  end

  def startup(options={})
    $tester.set_timeset("nvmbist", 40)
    $_captured_callbacks << "model1:startup"
  end

  def shutdown(options={})
    $_captured_callbacks << "model1:shutdown"
  end

  def before_top_level_reset
    $_captured_callbacks << "model1:before_top_level_reset"
  end

  def on_top_level_reset
    $_captured_callbacks << "model1:reset"
  end

  def after_top_level_reset
    $_captured_callbacks << "model1:after_top_level_reset"
  end
end

describe "Callbacks" do

  def clear_target
    Origen.app.unload_target!
    $_captured_callbacks = []
    $tester = OrigenTesters::J750.new
  end

  before :each do
    clear_target
    # Set the target to an empty function, this is to prevent the Pattern.create
    # calls below from instantiating the workspace default target which will
    # overwrite our test DUT objects
    Origen.target.temporary = -> {}
  end

  after :all do
    Origen.app.unload_target!
  end

  it "startup is called on TopLevel first" do
    dut = CallbacksSpecTopLevel.new
    model = CallbacksSpecTopLevelModel1.new
    Pattern.create do
    end
    $_captured_callbacks[0].should == "toplevel:startup"
    $_captured_callbacks[1].should == "model1:startup"

    clear_target
    model = CallbacksSpecTopLevelModel1.new
    dut = CallbacksSpecTopLevel.new
    Pattern.create do
    end
    $_captured_callbacks[0].should == "toplevel:startup"
    $_captured_callbacks[1].should == "model1:startup"
  end

  it "shutdown is called on TopLevel last" do
    dut = CallbacksSpecTopLevel.new
    model = CallbacksSpecTopLevelModel1.new
    Pattern.create do
    end
    $_captured_callbacks[2].should == "model1:shutdown"
    $_captured_callbacks[3].should == "toplevel:shutdown"

    clear_target
    model = CallbacksSpecTopLevelModel1.new
    dut = CallbacksSpecTopLevel.new
    Pattern.create do
    end
    $_captured_callbacks[2].should == "model1:shutdown"
    $_captured_callbacks[3].should == "toplevel:shutdown"
  end

  it "top-level reset method" do
    dut = CallbacksSpecTopLevel.new
    model = CallbacksSpecTopLevelModel1.new
    model.reg(:r1).write(0x1234_5678)
    model.reg(:r1).data.should == 0x1234_5678
    dut.reset
    model.reg(:r1).data.should == 0
    $_captured_callbacks[0].should == "model1:before_top_level_reset"
    $_captured_callbacks[1].should == "model1:reset"
    $_captured_callbacks[2].should == "model1:after_top_level_reset"
    $_captured_callbacks[3].should == nil

    clear_target
    dut = CallbacksSpecTopLevel.new
    model = CallbacksSpecTopLevelModel1.new
    model.reg(:r1).write(0x1234_5678)
    model.reg(:r1).data.should == 0x1234_5678
    dut.reset!
    model.reg(:r1).data.should == 0
    $_captured_callbacks[0].should == "model1:before_top_level_reset"
    $_captured_callbacks[1].should == "model1:shutdown"
    $_captured_callbacks[2].should == "toplevel:shutdown"
    $_captured_callbacks[3].should == "model1:reset"
    $_captured_callbacks[4].should == "toplevel:startup"
    $_captured_callbacks[5].should == "model1:startup"
    $_captured_callbacks[6].should == "model1:after_top_level_reset"
    $_captured_callbacks[7].should == nil
  end

  it "target should not reload on the first pattern generated in a thread" do
    $_load_count = 0
    Origen.load_target("configurable", dut: CallbacksSpecTopLevel)
    $dut.is_a?(CallbacksSpecTopLevel).should == true
    $_load_count.should == 1
    Pattern.create do
    end
    $_load_count.should == 1
    Pattern.create do
    end
    $_load_count.should == 2
  end

  it "test of generating program documentation from on_flow_end callback" do
    # Make sure this test always runs from a state where the program model has not
    # been generated yet, otherwise can get different behavior when running locally vs CI
    f = "#{Origen.root}/tmp/program_models/callback_test"
    FileUtils.rm_f(f) if File.exist?(f)

    files = ["#{Origen.root}/web/content/flows/probe_2_flow.md",
             "#{Origen.root}/web/content/flows.md"]

    files.each { |f| FileUtils.rm(f) if File.exist?(f) }

    class MyCallbackDUT
      include Origen::TopLevel

      def program_generated
        OrigenDocHelpers.generate_flow_docs layout: "#{Origen.root}/templates/web/layouts/_basic.html.erb", tab: :flows do |d|
          d.page  flow: :prb2,
                  name: "Probe 2 Flow",
                  target: "callback_test"  
        end
      end
    end

    Origen.target.temporary = "callback_test"

    ARGV = %w(program/prb2.rb)

    load "origen/commands/program.rb"

    files.each { |f| File.exist?(f).should == true }
    files.each { |f| FileUtils.rm(f) }
  end
end
