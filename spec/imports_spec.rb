require "spec_helper"

describe "Application imports" do

  before :all do
    RGen.load_target("debug")
  end

  it "methods can be overridden by the application" do
    $nvm.override_method.should == :overridden
  end

  it "methods can be added by the application" do
    $nvm.added_method.should == :added
  end

  it "RGen.root references within a plugin mean the top-level app root" do
    RGen.root.should == $dut.rgen_dot_root
  end

  it "RGen.root! references within a plugin mean the plugin root" do
    RGen.root.should_not == $dut.rgen_dot_root!
    File.exist?("#{$dut.rgen_dot_root!}/lib/c99/block.rb").should == true
  end

  it "RGen.root! references within a top level app are equivalent to RGen.root" do
    RGen.root!.should == RGen.root
  end

end
