require "spec_helper"

describe "Application Configuration" do

  it "captures the application name" do
    RGen.config.name.should == "RGen Core"
  end

  it "defaults to production mode" do
    RGen::Application::Configuration.new(RGen.app).mode.should == :production
  end

  specify "LSF configuration works" do
    RGen.config.lsf.debug.should == false
    RGen.config.lsf.debug = true
    RGen.config.lsf.debug.should == true
  end

  #specify "LSF configuration can be set from the application.rb file" do
  #  RGen.config.lsf.project.should == "rgen core"
  #end

end
