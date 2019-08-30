require "spec_helper"

USER_ENV_VARS = %w(ORIGEN_USER_ID ORIGEN_EMAIL ORIGEN_USER_EMAIL ORIGEN_NAME ORIGEN_USER_NAME)

def scrub_env_vars
  {}.tap do |newh|
    USER_ENV_VARS.each do |var|
      if ENV.keys.include? var
        newh[var] = ENV[var]
        ENV.delete var
      end
    end
  end
end

def restore_env_vars
  @orig_env_vars.each do |k,v|
    ENV[k] = v
  end
end

describe "a User" do
  before :all do
    # Remove any of the ENV user variables that the User class cares about or the spec tests will fail
    @orig_env_vars = scrub_env_vars
  end

  after :all do
    # Set the ENV back to its original state
    restore_env_vars
  end

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
  before :all do
    # Remove any of the ENV user variables that the User class cares about or the spec tests will fail
    @orig_env_vars = scrub_env_vars
  end
  after :all do
    # Set the ENV back to its original state
    restore_env_vars
  end
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
  it 'setting username with ENV works' do
    ENV['ORIGEN_USER_ID'] = 'ginty'
    u1 = User.new(:ignored_user_id)
    u1.id.should == 'ginty'
  end
  it 'can find the correct user password when using ENV variables' do
    ENV['ORIGEN_USER_ID'] = 'ginty'
    u1 = User.new
    expect { u1.password }.not_to raise_error
  end
end
