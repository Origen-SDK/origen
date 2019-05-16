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
      expect { Origen::Value.new(:h12Y4) }.to raise_error(Origen::HexStrValError)
    end

    it "converts to an integer and a string" do
      Origen::Value.new(:hA2_34).numeric?.should == true
      Origen::Value.new(:hA2_34).to_i.should == 0xA234
      Origen::Value.new(:hA2_34).to_s.should == "ha234"

      Origen::Value.new(:hA2_x4).numeric?.should == false
      Origen::Value.new(:hA2_x4).to_i.should == nil
      Origen::Value.new(:hA2_x4).to_s.should == "ha2x4"
      Origen::Value.new(:hA2_X4).to_s.should == "ha2X4"
    end

    it "discards bits that are out of range" do
      Origen::Value.new(:hA2_34, size: 8).to_i.should == 0x34
      Origen::Value.new(:hA2_FF, size: 6).to_s.should == 'hff'
      Origen::Value.new(:hA2_FF, size: 6).to_i.should == 0x3F
    end

    it "can extract bit values" do
      Origen::Value.new(:hf, size: 3)[0].should == 1
      Origen::Value.new(:hf, size: 3)[2].should == 1
      Origen::Value.new(:hf, size: 3)[3].should == nil
      Origen::Value.new(:hf, size: 3)[4].should == nil
      
      Origen::Value.new(:h1x)[0].x?.should == true
      Origen::Value.new(:h1x)[4].x?.should == false
      Origen::Value.new(:h1x)[4].should == 1
      Origen::Value.new(:h1x)[5].should == 0
    end
  end

  describe "Bin string values" do
    it "can be created" do
      v = Origen::Value.new(:b1010)
      v.value?.should == true
      v.bin_str_value?.should == true
    end

    it "will infer the size if not supplied" do
      v = Origen::Value.new(:b0101)
      v.size.should == 4
      v = Origen::Value.new(:b0101, size: 32)
      v.size.should == 32
      v = Origen::Value.new(:b1xx0_1101)
      v.size.should == 8
    end

    it "will reject invalid formatted values" do
      expect { Origen::Value.new(:b10yx) }.to raise_error(Origen::BinStrValError)
    end

    it "converts to an integer and a string" do
      Origen::Value.new(:b10_11).numeric?.should == true
      Origen::Value.new(:b10_11).to_i.should == 0b1011
      Origen::Value.new(:b10_11).to_s.should == "b1011"

      Origen::Value.new(:b10_x1).numeric?.should == false
      Origen::Value.new(:b10_x1).to_i.should == nil
      Origen::Value.new(:b10_x1).to_s.should == "b10x1"
      Origen::Value.new(:b10_X1).to_s.should == "b10x1"
    end

    it "discards bits that are out of range" do
      Origen::Value.new(:b10_11, size: 2).to_i.should == 0b11
      Origen::Value.new(:b10_11, size: 3).to_s.should == 'b011'
    end

    it "can extract bit values" do
      Origen::Value.new(:b10_11, size: 3)[0].should == 1
      Origen::Value.new(:b10_11, size: 3)[2].should == 0
      Origen::Value.new(:b10_11, size: 3)[3].should == nil
      Origen::Value.new(:b10_11, size: 3)[4].should == nil
      
      Origen::Value.new(:b1x0)[0].x?.should == false
      Origen::Value.new(:b1x0)[1].x?.should == true
      Origen::Value.new(:b1x0)[0].should == 0
      Origen::Value.new(:b1x0)[2].should == 1
    end
  end
end
