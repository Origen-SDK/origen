require "spec_helper"

# Some dummy classes to test out configurable targets
class MyDut1
  include Origen::TopLevel
  def initialize
    add_pin :pin1
    add_pin_alias :alias1, :pin1
  end
end

class MyDut2
  include Origen::TopLevel
  def initialize
    add_pin :pin1
  end
end

describe "Application Target" do

  before :each do
    Origen.load_application
  end

  it "is accessible via Origen.target" do
    Origen.target.should be
  end

  it "can be loaded" do
    Origen.target.temporary = "production"
    Origen.target.load!
    $top.should be
    $nvm.should be
  end

  it "reloading a target should not cause a duplicate pins error" do
    lambda do
      Origen.target.temporary = "debug"
      Origen.target.load!
      Origen.target.load!
      Origen.app.load_target!
      Origen.app.load_target!
    end.should_not raise_error
  end

  it "although duplicate pins should still be caught when appropriate" do
    lambda do
      Origen.target.temporary = "debug"
      Origen.target.load!
      C99::SOC.new
    end.should raise_error
  end

  it "ignores kwrite temp files" do
    begin
      `touch #{Origen.top}/target/debug.rb~`
      lambda do
        Origen.target.temporary = "debug"
      end.should_not raise_error
    ensure
      `rm -f #{Origen.top}/target/debug.rb~`
    end
  end

  it "can be used to switch to debug mode" do
    Origen.target.switch_to "debug"
    Origen.target.load!
    Origen.mode.should == :debug
  end

  specify "only recognized modes allowed" do
    [:production, :debug].each do |mode|
      lambda { Origen.mode = mode }.should_not raise_error
    end
    [:dummy, :data].each do |mode|
      lambda { Origen.mode = mode }.should raise_error
    end
  end

  specify "loading a target resets the mode" do
    Origen.mode = :debug
    Origen.mode.to_s.should == "debug"
    Origen.target.temporary = "production"
    Origen.target.load!
    Origen.mode.to_s.should == "production"
  end

  specify "recognizes moo numbers" do
    # In config/application.rb the prod targets are defined as:
    #  "1m79x" => "production"
    #  "2m79x" => "debug"
    Origen.target.temporary = "production"
    Origen.target.load!
    Origen.mode.to_s.should == "production"
    Origen.target.temporary = "2m79x"
    Origen.target.load!
    Origen.mode.to_s.should == "debug"
    Origen.target.temporary = "1m79x"
    Origen.target.load!
    Origen.mode.to_s.should == "production"
    Origen.target.temporary = "2M79X"
    Origen.target.load!
    Origen.mode.to_s.should == "debug"
    Origen.target.temporary = "1M79X"
    Origen.target.load!
    Origen.mode.to_s.should == "production"
    puts "******************** Missing target error expected here for 'm79x' ********************"
    lambda { Origen.target.temporary = "m79x" }.should raise_error
    puts "******************** Missing target error expected here for 'n86b' ********************"
    lambda { Origen.target.temporary = "n86b" }.should raise_error
  end

  it "returns the moo number (upcased)" do
    Origen.target.temporary = "production"
    Origen.target.load!
    Origen.target.moo.should == "1M79X"
    Origen.target.temporary = "debug"
    Origen.target.load!
    Origen.target.moo.should == "2M79X"
  end

  it "can find targets in sub directories of /target" do
    Origen.target.temporary = "debug"
    Origen.target.load!
    $tester.should_not == "found in subdir"
    Origen.target.temporary = "mock.rb"
    Origen.target.load!
    $tester.should == "found in subdir"
    # Works with MOO numbers
    Origen.target.temporary = "production"
    Origen.target.load!
    $tester.should_not == "found in subdir"
    Origen.target.temporary = "3M79X"
    Origen.target.load!
    $tester.should == "found in subdir"
    Origen.target.moo.should == "3M79X"
    # Symlinks don't work too well on windows...
    unless Origen.running_on_windows?
      # Works with symlinks
      Origen.target.temporary = "mock2"
      Origen.target.load!
      $tester.should == "found in symlinked subdir"
      Origen.target.temporary = "mock3"
      Origen.target.load!
      $tester.should == "found in subdir of a symlinked subdir!"
    end
  end

  it "can check if a target exists" do
    Origen.target.exist?("debug").should == true
    Origen.target.exists?("debug").should == true
    Origen.target.exist?("debug.rb").should == true
    Origen.target.exist?("some_other_debug").should == false
    Origen.target.exist?("mock").should == true
    # Symlinks don't work too well on windows...
    unless Origen.running_on_windows?
      Origen.target.exist?("mock2").should == true
      Origen.target.exist?("mock3").should == true
    end
  end

  it "can check if a target name is unique" do
    Origen.target.unique?("v93k").should == true
    # Symlinks don't work too well on windows...
    unless Origen.running_on_windows?
      Origen.target.unique?("mock").should == false
    end
  end

  it "configurable targets work" do
    Origen.load_target("configurable", tester: OrigenTesters::J750, dut: C99::SOC)
    $tester.j750?.should == true
    $top.is_a?(C99::SOC).should == true
    Origen.load_target("configurable", tester: OrigenTesters::V93K, dut: C99::NVM)
    $tester.v93k?.should == true
    $top.is_a?(C99::NVM).should == true
  end

  it "caches are cleared between reloads of configurable targets with different options" do
    Origen.load_target("configurable", tester: OrigenTesters::J750, dut: MyDut1)
    $dut.has_pin?(:pin1).should == true
    $dut.has_pin?(:alias1).should == true
    Origen.load_target("configurable", tester: OrigenTesters::V93K, dut: MyDut2)
    $dut.has_pin?(:pin1).should == true
    $dut.has_pin?(:alias1).should == false
  end

  it "leave with the debug target set" do
    Origen.load_target("debug")
  end

  it "all_targets does not return target dir itself" do
    Origen.target.all_targets.should_not == ["target"]
  end
   
  it "all_targets is able to find individual targets" do
    Origen.target.all_targets.include?("production.rb").should == true
    Origen.target.all_targets.include?("debug.rb").should == true
  end

  it "all_targets is able to find targets in subdirs" do
    Origen.target.all_targets.include?("mock.rb").should == true
    # Symlinks don't work too well on windows...
    unless Origen.running_on_windows?
      Origen.target.all_targets.include?("mock2.rb").should == true
      Origen.target.all_targets.include?("mock3.rb").should == true
    end
  end

end
