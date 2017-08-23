require 'spec_helper'

describe "Origen.site_config" do

  # Make sure that cached site config values don't affect these or the
  # next tests
  before :each do
    Origen.instance_variable_set("@site_config", nil)
  end

  after :all do
    Origen.instance_variable_set("@site_config", nil)
  end

  def with_env_variable(var, value)
    orig = ENV[var]
    ENV[var] = value
    yield
    ENV[var] = orig
  end

  it "converts true/false values from environment variables to booleans" do
    with_env_variable("ORIGEN_GEM_MANAGE_BUNDLER", "false") do
      ENV["ORIGEN_GEM_MANAGE_BUNDLER"].should == "false"
      Origen.site_config.gem_manage_bundler.should == false
    end
  end
end
