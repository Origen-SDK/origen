require "spec_helper"

describe "RGen.mode" do

  it "is an alias of RGen.app.config.mode" do
    RGen.mode.should == RGen.app.config.mode
    RGen.mode.should == RGen.config.mode
  end

  it "returns an instance of RGen::Mode" do
    RGen.mode.class.should == RGen::Mode
  end

  it "the mode can be set by assigning a symbol" do
    RGen.config.mode = :debug
    RGen.mode.class.should == RGen::Mode
    RGen.mode.debug?.should == true
    RGen.mode = :production
    RGen.mode.class.should == RGen::Mode
    RGen.mode.debug?.should == false
  end

  it "can be frozen" do
    RGen.mode = :debug
    RGen.mode.debug?.should == true
    RGen.mode.freeze
    RGen.mode = :production
    RGen.mode.debug?.should == true
    RGen.mode.unfreeze
    RGen.mode = :production
    RGen.mode.debug?.should == false
  end

  it "it can be compared to a symbol" do
    RGen.mode = :debug
    RGen.mode.class.should == RGen::Mode
    (RGen.mode == :debug).should == true
    (RGen.mode == :production).should == false
    RGen.mode = :production
    RGen.mode.class.should == RGen::Mode
    (RGen.mode == :debug).should == false
    (RGen.mode == :production).should == true
  end

  it "simulation is considered a debug mode" do
    RGen.mode = :simulation
    RGen.mode.simulation?.should == true
    RGen.mode.debug?.should == true
  end

  it "is production by default" do
    RGen::Mode.new.production?.should == true
  end

  it "can be set by an abbreviation" do
    RGen.mode = :debug
    (RGen.mode == :debug).should == true
    RGen.mode = "prod"
    (RGen.mode == :production).should == true
    RGen.mode = "de"
    (RGen.mode == :debug).should == true
    RGen.mode = "sim"
    (RGen.mode == :simulation).should == true
  end

end
