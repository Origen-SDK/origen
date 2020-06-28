require "spec_helper"

describe "The plugins API" do

  before :all do
    Origen.load_target("debug")
    Origen.app.plugins.temporary = nil
  end

  it "returns an enhanced array containing all plugin app instances" do
    Origen.app.plugins.size.should == 7
    Origen.app.plugins.is_a?(Origen::Application::Plugins).should == true
  end

  it "can set and get the current plugin" do
    Origen.app.plugins.current = :origen_testers
    # Legacy API
    Origen.app.current_plugin.name.should == :origen_testers
    Origen.app.plugins.current.name == :origen_testers
    cmd("origen pl").should include("Current plugin is: origen_testers")
    # Legacy API
    Origen.app.current_plugin.default = :origen_debuggers
    # Legacy API
    Origen.app.current_plugin.name.should == :origen_debuggers
    Origen.app.plugins.current.name == :origen_debuggers
    cmd("origen pl").should include("Current plugin is: origen_debuggers")
    Origen.app.plugins.current = nil
    Origen.app.plugins.current.should == nil
    cmd("origen pl").should include("No plugin set!")
    Origen.app.plugins.current = :origen_debuggers
    # Legacy API
    Origen.app.current_plugin.temporary = :origen_testers
    Origen.app.plugins.current.name.should == :origen_testers
    Origen.app.plugins.temporary = :origen_core_support
    Origen.app.plugins.current.name.should == :origen_core_support
    Origen.app.plugins.temporary = nil
    Origen.app.plugins.current.name.should == :origen_debuggers
    Origen.app.plugins.current = nil
    Origen.app.plugins.current.should == nil
  end

  it "can temporarily disable the current plugin" do
    Origen.app.plugins.current = :origen_testers
    Origen.app.plugins.current.should_not == nil
    Origen.app.plugins.disable_current
    Origen.app.plugins.current.should == nil
    Origen.app.plugins.enable_current
    Origen.app.plugins.current.should_not == nil
    Origen.app.plugins.disable_current do
      Origen.app.plugins.current.should == nil
    end
    Origen.app.plugins.current.should_not == nil
  end

  it "Origen.root references within a plugin mean the top-level app root" do
    Origen.root.should == $dut.origen_dot_root
  end

  it "Origen.root! references within a plugin mean the plugin root" do
    Origen.root.should_not == $dut.origen_dot_root!
    File.exist?("#{$dut.origen_dot_root!}/app/lib/origen_core_support/block.rb").should == true
  end

  it "Origen.root! references within a top level app are equivalent to Origen.root" do
    Origen.root!.should == Origen.root
  end

  it "Origen.app references within a plugin mean the top-level app" do
    Origen.app.should == $dut.origen_dot_app
  end

  it "Origen.app! references within a plugin mean the plugin app" do
    Origen.app.should_not == $dut.origen_dot_root!
    File.exist?("#{$dut.origen_dot_app!.root}/app/lib/origen_core_support/block.rb").should == true
  end

  it "Origen.app! references within a top level app are equivalent to Origen.app" do
    Origen.app!.should == Origen.app
  end

  it "Shared commands work" do
    cmd("origen core_support:test").should =~ /^This is a test command to test the command sharing capability of plugins/
  end
  
  context 'with a default plugin set by the application' do
    before(:context) do
      # Force the application's configuration to have a default plugin
      expect(Origen.app.config.default_plugin).to be(nil)
      Origen.app.config.default_plugin = :origen_testers
      expect(Origen.app.config.default_plugin).to eql(:origen_testers)
      
      @plugin = Origen.app.plugins.current ? Origen.app.plugins.current.name : nil
      Origen.app.plugins.current = nil

      @plugin_cleared = Origen.app.session.origen_core[:default_plugin_cleared_by_user]
      Origen.app.session.origen_core[:default_plugin_cleared_by_user] = false

      expect(Origen.app.plugins.instance_variable_get(:@current)).to be(nil)
    end
    
    it "Uses the default plugin if the user hasn't manually cleared it" do
      expect(Origen.app.plugins.current).to_not be(nil)
      expect(Origen.app.plugins.current.name).to eql(:origen_testers)
      expect(Origen.app.plugins.instance_variable_get(:@current)).to_not be(nil)
    end
    
    it "Allows the user to override the default plugin, as normal" do
      Origen.app.plugins.current = :origen_core_support
      expect(Origen.app.plugins.current).to_not be(nil)
      expect(Origen.app.plugins.current.name).to eql(:origen_core_support)
    end
    
    it "Allows the user to clear the current plugin, as normal, but also disabling the default plugin" do
      Origen.app.plugins.current = nil
      Origen.app.session.origen_core[:default_plugin_cleared_by_user] = true
      expect(Origen.app.plugins.current).to be(nil)
      expect(Origen.app.plugins.instance_variable_get(:@current)).to be(nil)
    end
    
    after(:context) do
      # Remove the force
      Origen.app.config.default_plugin = nil
      expect(Origen.app.config.default_plugin).to be(nil)
      
      Origen.app.session.origen_core[:default_plugin_cleared_by_user] = @plugin_cleared
      Origen.app.plugins.current = @plugin
    end
  end
end
