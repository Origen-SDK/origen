require "spec_helper"

module Origen

  class MyModel
    include Origen::Model
    def initialize
      reg :reg1, 0 do
        bits 31..0, :data
      end
    end

    def hello_model
      "yo"
    end
  end

  class MyModel2
    include Origen::Model
    def hello_model
      "yo2"
    end
  end

  class MyModel3 < MyModel
    def hello_model
      "yo3"
    end
  end

  class MyModel4
    include Origen::Model
    def hello_model
      "yo4"
    end
  end

  class MyModel5 < MyModel4
    def hello_model
      "yo5"
    end
  end

  class MyController
    include Origen::Controller
    model class_name: "MyModel"
    model class_name: "MyModel2"

    def hello_controller
      "hi"
    end

    def write_register(reg, options={})
      $written = true
    end
  end

  class MyModel4Controller
    def hello_controller
      "hi4"
    end
  end

  class PathControl
    include Origen::Controller
    model path: "$nvm"
  end

  module Tmp
    class Model
      include Origen::Model
    end

    class ModelController
      def hi
        "yo"
      end
    end

    class TopLevel
      include Origen::TopLevel

      def a_top_level_method
      end
    end

    class TopLevelController
      def startup(options)
        $called_count ||= 0
        $called_count += 1
      end

      def wrapped?
        true
      end

      def a_controller_method
      end
    end
  end

  describe "Controller" do
    it "wraps instantiated models automagically" do
      m = MyModel.new
      m.hello_controller.should == "hi"
    end

    it "it looks like the model when asked" do
      MyModel.new.is_a?(MyModel).should == true
    end

    it "it also looks like a controller" do
      MyModel.new.is_a?(MyController).should == true
    end

    it "proxies missing methods to the model" do
      MyModel.new.hello_model.should == "yo"
    end

    it "respond to works correctly" do
      m = MyModel.new
      m.respond_to?(:hello_model).should == true
      m.respond_to?(:hello_controller).should == true
    end

    it "controllers can wrap multiple model classes" do
      MyModel2.new.hello_model.should == "yo2"
    end

    it "wraps sub classes" do
      m = MyModel3.new
      m.hello_model.should == "yo3"
      m.hello_controller.should == "hi"
    end

    it "can be inferred from the class name" do
      m = MyModel4.new
      m.hello_model.should == "yo4"
      m.hello_controller.should == "hi4"
      m = MyModel5.new
      m.hello_model.should == "yo5"
      m.hello_controller.should == "hi4"
      # Verify this works within a namespace
      Tmp::Model.new.hi.should == "yo"
    end

    it "controllers can implement write_register" do
      $written = false
      MyModel.new.reg1.write!(1)
      $written.should == true
    end

    it "path references work for the model path" do
      Origen.load_target("debug")
      c = PathControl.new
      c.mclkdiv.clkdiv.data.should == 0x18
    end

    it "controllers can implement callbacks" do
      $called_count.should == nil
      Origen.target.temporary = -> do
        $dut = Tmp::TopLevel.new
        $tester = OrigenTesters::J750.new
      end
      Origen.target.load!
      Pattern.create do
        $tester.set_timeset("nvmbist", 40)
        # Verify that both can be called on Origen.top_level
        Origen.top_level.a_top_level_method
        Origen.top_level.a_controller_method
      end
      $dut.wrapped?.should == true
      $called_count.should == 1
      Origen.target.temporary = nil
      Origen.app.unload_target!
    end
  end
end
