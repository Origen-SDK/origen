require 'spec_helper'

describe "An application's app/ dir" do

  it "can load an app's models without a require" do
    m = OrigenCoreSupport::MySimpleModel.new
    m.test_model.should == "model"
  end

  it "a model's controller is loaded without a require" do
    m = OrigenCoreSupport::MySimpleModel.new
    m.test_controller.should == "controller"
  end
end
