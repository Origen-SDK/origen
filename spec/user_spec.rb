require "spec_helper"

describe "a User" do

  #it "can be created with a name and number" do
  #  u = User.new("Blah", "r49409")
  #  u.name.should == "Stephen McGinty"
  #  u.core_id.should == "r49409"
  #  u.initials.should == "sm"
  #  u.admin?.should == false
  #  u = User.new("Blah Blah", "r49409", :admin)
  #  u.name.should == "Stephen McGinty"
  #  u.core_id.should == "r49409"
  #  u.initials.should == "sm"
  #  u.admin?.should == true
  #end

  it "can be created with a number only" do
    u = User.new("r49409")
    u.core_id.should == "r49409"
    u.admin?.should == false
    u = User.new("r49409", :admin)
    u.core_id.should == "r49409"
    u.admin?.should == true
  end

  #it "the name will automatically fill in from the core directory" do
  #  u = User.new("r49409")
  #  u.core_id.should == "r49409"
  #  u.name.should == "Stephen McGinty"
  #end

  it "users can be compared for equality" do
    u1 = User.new("r49409")
    u2 = User.new("r6aanf")
    u3 = User.new("r49409")
    (u1 == u3).should == true
    (u1 == u2).should == false
    (u1 == "r49409").should == true
  end

end
