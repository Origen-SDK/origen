require "spec_helper"

module RGen

  class MyModel
    include RGen::Model
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
    include RGen::Model
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
    include RGen::Model
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
    include RGen::Controller
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
    include RGen::Controller
    model path: "$nvm"
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
    end

    it "controllers can implement write_register" do
      $written = false
      MyModel.new.reg1.write!(1)
      $written.should == true
    end

    it "path references work for the model path" do
      RGen.load_target("debug")
      c = PathControl.new
      c.mclkdiv.clkdiv.data.should == 0x18
    end
  end
end
