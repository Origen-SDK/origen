require "spec_helper"

describe "Environment" do

  it "is accessible via Origen.environment" do
    Origen.environment.should be
  end

  it "can be tested for presence" do
    Origen.environment.exists?('test').should == true
    Origen.environment.exists?('test1').should == true
    Origen.environment.exists?('testX').should == false
    Origen.environment.unique?('test').should == false
    Origen.environment.unique?('testX').should == false
    Origen.environment.unique?('test1').should == true
  end

  it "can be loaded" do
    Origen.environment.temporary = "test1"
    Origen.target.load!
    $env_var.should == 1
    Origen.environment.temporary = "test2"
    Origen.target.load!
    $env_var.should == 2
  end

  it "ignores kwrite temp files" do
    begin
      `touch #{Origen.top}/environment/test1.rb~`
      lambda do
        Origen.environment.temporary = "test1"
      end.should_not raise_error
    ensure
      `rm -f #{Origen.top}/environment/test1.rb~`
    end
  end

  it "all_environments does not return environment dir itself" do
    Origen.environment.all_environments.include?("environment").should == false
  end
   
  it "all_environments is able to find individual environments" do
    Origen.environment.all_environments.include?("test1.rb").should == true
    Origen.environment.all_environments.include?("test2.rb").should == true
  end

  specify "environment command works" do
    Origen.environment.default = nil
    output = `origen e`
    output.should include "No environment has been specified"
    begin
      output = `origen e test2`
      output = `origen e`
      output.should_not include "No environment has been specified"
      output.should include "$env_var = 2"
    ensure
      Origen.environment.default = nil
    end
  end
end
