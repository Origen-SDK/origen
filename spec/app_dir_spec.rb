require 'spec_helper'

describe "An application's app/ dir" do

  after :all do
    Origen.app.unload_target!
  end

  it "can load an app's models without a require" do
    m = OrigenCoreSupport::MySimpleModel.new
    m.test_model.should == "model"
  end

  it "a model's controller is loaded without a require" do
    m = OrigenCoreSupport::MySimpleModel.new
    m.test_controller.should == "controller"
  end

  it "attribute.rb files create attributes and can override" do
    nvm = OrigenCoreSupport::NVM.new
    nvm2 = OrigenCoreSupport::NVM::NVMSub.new

    nvm.address_width.should == 16
    nvm2.address_width.should == 12
    nvm.data_width.should == 32
    nvm2.data_width.should == 32
    nvm.has_feature_x.should == true
    nvm2.has_feature_x.should == false
    nvm.has_feature_x?.should == true
    nvm2.has_feature_x?.should == false
    nvm.has_feature_y.should == false
    nvm2.has_feature_y.should == false
    nvm.has_feature_y?.should == false
    nvm2.has_feature_y?.should == false
    nvm.has_feature_z.should == false
    nvm2.has_feature_z.should == true
    nvm.has_feature_z?.should == false
    nvm2.has_feature_z?.should == true

    nvm.attributes.should == {address_width: 16,
                              data_width: 32,
                              has_feature_x: true,
                              has_feature_y: false,
                              has_feature_z: false}

    nvm2.attributes.should == {address_width: 12,
                               data_width: 32,
                               has_feature_x: false,
                               has_feature_y: false,
                               has_feature_z: true}
  end

end
