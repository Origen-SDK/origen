require "spec_helper"

describe "Application imports" do

  before :all do
    Origen.load_target("debug")
  end

  it "methods can be overridden by the application" do
    $nvm.override_method.should == :overridden
  end

  it "methods can be added by the application" do
    $nvm.added_method.should == :added
  end

  it "Origen.root references within a plugin mean the top-level app root" do
    Origen.root.should == $dut.origen_dot_root
  end

  it "Origen.root! references within a plugin mean the plugin root" do
    Origen.root.should_not == $dut.origen_dot_root!
    File.exist?("#{$dut.origen_dot_root!}/lib/c99/block.rb").should == true
  end

  it "Origen.root! references within a top level app are equivalent to Origen.root" do
    Origen.root!.should == Origen.root
  end

end
