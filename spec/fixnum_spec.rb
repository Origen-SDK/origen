require 'spec_helper'

describe Fixnum do

  specify "part select helpers work" do
    0x123456[7,0].should == 0x56
    0x123456[7..0].should == 0x56
    0x123456[15,0].should == 0x3456
    0x123456[15..0].should == 0x3456
    0x123456[23,16].should == 0x12
    0x123456[23..16].should == 0x12
  end

  specify "original bit select still works" do
    0x12[0].should == 0
    0x12[1].should == 1
    0x12[2].should == 0
    0x12[3].should == 0
    0x12[4].should == 1
    0x12[5].should == 0
  end

  specify "ones complement helper works" do
    0x10.ones_comp(8).should == 0b11101111
  end

end
