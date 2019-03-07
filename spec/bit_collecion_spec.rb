require 'spec_helper'

module BitCollectionTest
  
  describe Origen::Registers::BitCollection do

    include Origen::Registers

    it "status_str works on non-nibble aligned regs" do
      reg :r1, 0 do
        bits 10..0, :b1
      end
      r1.b1.status_str(:write).should == "000"
      r1.b1.status_str(:read).should == "[xxx]XX"
      r1.b1.read
      r1.b1.status_str(:read).should == "000"
      r1.b1.read(0xFFF)
      r1.b1.status_str(:read).should == "7FF"
    end
  end
end
