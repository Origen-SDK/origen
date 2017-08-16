require 'spec_helper'

describe "Origen.site_config" do

  it "converts true/false values from environment variables to booleans" do
    ENV["ORIGEN_GEM_MANAGE_BUNDLER"] = "false"
    ENV["ORIGEN_GEM_MANAGE_BUNDLER"].should == "false"
    Origen.site_config.gem_manage_bundler.should == false
  end
end
