require "spec_helper"

describe Origen::Value do
  describe "Hex string values" do
    it "can be created" do
      v = Origen::Value.new(:h1234)
      v.value?.should == true
      v.hex_str_value?.should == true
    end

    it "will infer the size if not supplied" do
      v = Origen::Value.new(:h1234)
      v.size.should == 16
      v = Origen::Value.new(:h1234, size: 32)
      v.size.should == 32
      v = Origen::Value.new(:h1234_5678)
      v.size.should == 32
    end

    it "will reject invalid formatted values" do
      expect { Origen::Value.new(:h12Y4) }.to raise_error(Origen::SyntaxError)
    end

    it "converts to an integer and a string" do
      Origen::Value.new(:hA2_34).numeric?.should == true
      Origen::Value.new(:hA2_34).to_i.should == 0xA234
      Origen::Value.new(:hA2_34).to_s.should == "a234"

      Origen::Value.new(:hA2_x4).numeric?.should == false
      Origen::Value.new(:hA2_x4).to_i.should == nil
      Origen::Value.new(:hA2_x4).to_s.should == "a2x4"
      Origen::Value.new(:hA2_X4).to_s.should == "a2X4"


    end
  end
end
