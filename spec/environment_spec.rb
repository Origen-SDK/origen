require "spec_helper"

describe "Environment" do

  it "is accessible via RGen.environment" do
    RGen.environment.should be
  end

  it "can be tested for presence" do
    RGen.environment.exists?('test').should == true
    RGen.environment.exists?('test1').should == true
    RGen.environment.exists?('testX').should == false
    RGen.environment.unique?('test').should == false
    RGen.environment.unique?('testX').should == false
    RGen.environment.unique?('test1').should == true
  end

  it "can be loaded" do
    RGen.environment.temporary = "test1"
    RGen.target.load!
    $env_var.should == 1
    RGen.environment.temporary = "test2"
    RGen.target.load!
    $env_var.should == 2
  end

  it "ignores kwrite temp files" do
    begin
      `touch #{RGen.top}/environment/test1.rb~`
      lambda do
        RGen.environment.temporary = "test1"
      end.should_not raise_error
    ensure
      `rm -f #{RGen.top}/environment/test1.rb~`
    end
  end

  it "all_environments does not return environment dir itself" do
    RGen.environment.all_environments.include?("environment").should == false
  end
   
  it "all_environments is able to find individual environments" do
    RGen.environment.all_environments.include?("test1.rb").should == true
    RGen.environment.all_environments.include?("test2.rb").should == true
  end

  specify "environment command works" do
    RGen.environment.default = nil
    output = `rgen e`
    output.should include "No environment has been specified"
    begin
      output = `rgen e test2`
      output = `rgen e`
      output.should_not include "No environment has been specified"
      output.should include "$env_var = 2"
    ensure
      RGen.environment.default = nil
    end
  end
end
