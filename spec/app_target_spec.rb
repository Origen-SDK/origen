require "spec_helper"

# Some dummy classes to test out configurable targets
class MyDut1
  include RGen::Pins
  def initialize
    add_pin :pin1
    add_pin_alias :alias1, :pin1
  end
end

class MyDut2
  include RGen::Pins
  def initialize
    add_pin :pin1
  end
end

describe "Application Target" do

  before :each do
    RGen.load_application
  end

  it "is accessible via RGen.target" do
    RGen.target.should be
  end

  it "can be loaded" do
    RGen.target.temporary = "production"
    RGen.target.load!
    $top.should be
    $nvm.should be
  end

  it "reloading a target should not cause a duplicate pins error" do
    lambda do
      RGen.target.temporary = "debug"
      RGen.target.load!
      RGen.target.load!
      RGen.app.load_target!
      RGen.app.load_target!
    end.should_not raise_error
  end

  it "although duplicate pins should still be caught when appropriate" do
    lambda do
      RGen.target.temporary = "debug"
      RGen.target.load!
      C99::SOC.new
    end.should raise_error
  end

  it "ignores kwrite temp files" do
    begin
      `touch #{RGen.top}/target/debug.rb~`
      lambda do
        RGen.target.temporary = "debug"
      end.should_not raise_error
    ensure
      `rm -f #{RGen.top}/target/debug.rb~`
    end
  end

  it "can be used to switch to debug mode" do
    RGen.target.switch_to "debug"
    RGen.target.load!
    RGen.config.mode.should == :debug
  end

  specify "only recognized modes allowed" do
    [:production, :debug].each do |mode|
      lambda { RGen.config.mode = mode }.should_not raise_error
    end
    [:dummy, :data].each do |mode|
      lambda { RGen.config.mode = mode }.should raise_error
    end
  end

  specify "loading a target resets the mode" do
    RGen.config.mode == :debug
    RGen.target.temporary = "production"
    RGen.target.load!
    RGen.config.mode.should == :production
  end

  specify "recognizes moo numbers" do
    # In config/application.rb the prod targets are defined as:
    #  "1m79x" => "production"
    #  "2m79x" => "debug"
    RGen.target.temporary = "production"
    RGen.target.load!
    RGen.config.mode.should == :production
    RGen.target.temporary = "2m79x"
    RGen.target.load!
    RGen.config.mode.should == :debug
    RGen.target.temporary = "1m79x"
    RGen.target.load!
    RGen.config.mode.should == :production
    RGen.target.temporary = "2M79X"
    RGen.target.load!
    RGen.config.mode.should == :debug
    RGen.target.temporary = "1M79X"
    RGen.target.load!
    RGen.config.mode.should == :production
    puts "******************** Missing target error expected here for 'm79x' ********************"
    lambda { RGen.target.temporary = "m79x" }.should raise_error
    puts "******************** Missing target error expected here for 'n86b' ********************"
    lambda { RGen.target.temporary = "n86b" }.should raise_error
  end

  it "returns the moo number (upcased)" do
    RGen.target.temporary = "production"
    RGen.target.load!
    RGen.target.moo.should == "1M79X"
    RGen.target.temporary = "debug"
    RGen.target.load!
    RGen.target.moo.should == "2M79X"
  end

  it "can find targets in sub directories of /target" do
    RGen.target.temporary = "debug"
    RGen.target.load!
    $tester.should_not == "found in subdir"
    RGen.target.temporary = "mock.rb"
    RGen.target.load!
    $tester.should == "found in subdir"
    # Works with MOO numbers
    RGen.target.temporary = "production"
    RGen.target.load!
    $tester.should_not == "found in subdir"
    RGen.target.temporary = "3M79X"
    RGen.target.load!
    $tester.should == "found in subdir"
    RGen.target.moo.should == "3M79X"
    # Symlinks don't work too well on windows...
    unless RGen.running_on_windows?
      # Works with symlinks
      RGen.target.temporary = "mock2"
      RGen.target.load!
      $tester.should == "found in symlinked subdir"
      RGen.target.temporary = "mock3"
      RGen.target.load!
      $tester.should == "found in subdir of a symlinked subdir!"
    end
  end

  it "can check if a target exists" do
    RGen.target.exist?("debug").should == true
    RGen.target.exists?("debug").should == true
    RGen.target.exist?("debug.rb").should == true
    RGen.target.exist?("some_other_debug").should == false
    RGen.target.exist?("mock").should == true
    # Symlinks don't work too well on windows...
    unless RGen.running_on_windows?
      RGen.target.exist?("mock2").should == true
      RGen.target.exist?("mock3").should == true
    end
  end

  it "can check if a target name is unique" do
    RGen.target.unique?("v93k").should == true
    # Symlinks don't work too well on windows...
    unless RGen.running_on_windows?
      RGen.target.unique?("mock").should == false
    end
  end

  it "configurable targets work" do
    RGen.load_target("configurable", tester: RGen::Tester::J750, dut: C99::SOC)
    $tester.j750?.should == true
    $top.is_a?(C99::SOC).should == true
    RGen.load_target("configurable", tester: RGen::Tester::V93K, dut: C99::NVM)
    $tester.v93k?.should == true
    $top.is_a?(C99::NVM).should == true
  end

  it "caches are cleared between reloads of configurable targets with different options" do
    RGen.load_target("configurable", tester: RGen::Tester::J750, dut: MyDut1)
    $dut.has_pin?(:pin1).should == true
    $dut.has_pin?(:alias1).should == true
    RGen.load_target("configurable", tester: RGen::Tester::V93K, dut: MyDut2)
    $dut.has_pin?(:pin1).should == true
    $dut.has_pin?(:alias1).should == false
  end

  it "leave with the debug target set" do
    RGen.load_target("debug")
  end

  it "all_targets does not return target dir itself" do
    RGen.target.all_targets.should_not == ["target"]
  end
   
  it "all_targets is able to find individual targets" do
    RGen.target.all_targets.include?("production.rb").should == true
    RGen.target.all_targets.include?("debug.rb").should == true
  end

  it "all_targets is able to find targets in subdirs" do
    RGen.target.all_targets.include?("mock.rb").should == true
    # Symlinks don't work too well on windows...
    unless RGen.running_on_windows?
      RGen.target.all_targets.include?("mock2.rb").should == true
      RGen.target.all_targets.include?("mock3.rb").should == true
    end
  end

end
