require 'spec_helper'

describe "Origen.site_config" do

  # Make sure that cached site config values don't affect these or the
  # next tests
  before :each do
    clear_site_config
  end

  after :all do
    clear_site_config
  end

  def clear_site_config
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
    with_env_variable("ORIGEN_GEM_MANAGE_BUNDLER", "true") do
      ENV["ORIGEN_GEM_MANAGE_BUNDLER"].should == "true"
      clear_site_config
      Origen.site_config.gem_manage_bundler.should == true
    end
  end
  
  it "allows user overrides" do
    with_env_variable("ORIGEN_USER_GEM_DIR", "C:\test\path") do
      ENV["ORIGEN_USER_GEM_DIR"].should == "C:\test\path"
      Origen.site_config.gem_install_dir.should == "C:\test\path"
    end
    with_env_variable("ORIGEN_USER_INSTALL_DIR", "~/other/path") do
      ENV["ORIGEN_USER_INSTALL_DIR"].should == "~/other/path"
      Origen.site_config.user_install_dir.should == "~/other/path"
    end
  end
end
