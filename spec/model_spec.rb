require "spec_helper"

module ModelSpec
  class MyModel
    include Origen::Model
    attr_reader :my_version
    attr_accessor :mode_changed_count
    def initialize
      @my_version = version
       add_mode :mode1
      @mode_changed_count = 0
    end
    
    def on_mode_changed(options)
      @mode_changed_count += 1
    end
  end

  class Base
    include Origen::Model
    attr_reader :some_val
    def initialize(version, options={})
      @some_val = "hello"
    end
  end

  class P2 < Base
    def initialize(version, options={})
      super
    end
  end

  describe "Origen Models" do

    it "will extract a version from the intialization arguments" do
      m = MyModel.new(2)
      m.version.should == 2
      m = MyModel.new(version: 3)
      m.version.should == 3
      m = MyModel.new("blah")
      m.version.should == nil
    end

    it "version should be set before initialize" do
      MyModel.new(4).my_version.should == 4
      MyModel.new(version: 4).my_version.should == 4
    end

    it "various attributes can be tried for a match" do
      m = MyModel.new(5)
      m.try(:blah, :blah_blah).should == nil
      m.try(:pdm_version, :version).should == 5
    end

    it "model hierarchy from c90tfs micros works" do
      P2.new(2, blah: 3).some_val.should == "hello"
      P2.new(2, blah: 3).version.should == 2
    end
    
    it 'on_mode_changed callback works' do
      m = MyModel.new
      m.modes.should == [:mode1]
      m.mode.should == nil
      m.mode_changed_count.should == 0
      m.mode = :mode1
      m.mode_changed_count.should == 1
    end
  end
end
