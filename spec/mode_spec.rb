require "spec_helper"

describe "Origen.mode" do

  it "is an alias of Origen.app.config.mode" do
    Origen.mode.should == Origen.app.config.mode
    Origen.mode.should == Origen.config.mode
  end

  it "returns an instance of Origen::Mode" do
    Origen.mode.class.should == Origen::Mode
  end

  it "the mode can be set by assigning a symbol" do
    Origen.config.mode = :debug
    Origen.mode.class.should == Origen::Mode
    Origen.mode.debug?.should == true
    Origen.mode = :production
    Origen.mode.class.should == Origen::Mode
    Origen.mode.debug?.should == false
  end

  it "can be frozen" do
    Origen.mode = :debug
    Origen.mode.debug?.should == true
    Origen.mode.freeze
    Origen.mode = :production
    Origen.mode.debug?.should == true
    Origen.mode.unfreeze
    Origen.mode = :production
    Origen.mode.debug?.should == false
  end

  it "it can be compared to a symbol" do
    Origen.mode = :debug
    Origen.mode.class.should == Origen::Mode
    (Origen.mode == :debug).should == true
    (Origen.mode == :production).should == false
    Origen.mode = :production
    Origen.mode.class.should == Origen::Mode
    (Origen.mode == :debug).should == false
    (Origen.mode == :production).should == true
  end

  it "simulation is considered a debug mode" do
    Origen.mode = :simulation
    Origen.mode.simulation?.should == true
    Origen.mode.debug?.should == true
  end

  it "is production by default" do
    Origen::Mode.new.production?.should == true
  end

  it "can be set by an abbreviation" do
    Origen.mode = :debug
    (Origen.mode == :debug).should == true
    Origen.mode = "prod"
    (Origen.mode == :production).should == true
    Origen.mode = "de"
    (Origen.mode == :debug).should == true
    Origen.mode = "sim"
    (Origen.mode == :simulation).should == true
  end

end
