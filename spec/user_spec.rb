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

describe 'Advanced User Options' do
  it 'Switch User should work' do
    original_user = Origen.current_user
    new_user = User.new('crradm')
    Origen.with_user(new_user) do 
      Origen.current_user.id.should == 'crradm'
      Origen.current_user.id.should_not == original_user.id
    end
    Origen.current_user.id.should == original_user.id
    Origen.current_user.id.should_not == 'crradm'
  end

  it 'Checks if a different user id is specified in Origen Site Config' do
    if !Origen.site_config.change_user_id
      Origen.site_config.change_user_id = false
      Origen.site_config.user_id = nil
    else
      Origen.site_config.change_user_id = Origen.site_config.change_user_id
      Origen.site_config.user_id = Origen.site_config.user_id
    end
  end
end
