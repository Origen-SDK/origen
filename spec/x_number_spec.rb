require 'spec_helper'

describe 'XNumbers' do
  def x(sym)
    Origen::XNumber.new(sym)
  end

  it 'can be created' do
    n = x(:b4_1xxx)
    n.size.should == 4
    n.mask.should == 0b1000
    n.to_s.should == '0b1XXX'

    n = x(:b4_1X)
    n.size.should == 4
    n.mask.should == 0b1110
    n.to_s.should == '0b001X'
    n = x(:h16_5X)
    n.size.should == 16
    n.mask.should == 0xFFF0
    n.to_s.should == '0x005X'
  end

  it "X means don't care in equality statements" do
    n = x(:b4_01X1)
    (n == 0b0101).should == true
    (n == 0b0111).should == true
    (n == 0b10111).should == false
    (n == 0b1111).should == false
    (n == 0b0100).should == false

    n = x(:h16_12XX)
    (n == 0x1234).should == true
    (n == 0x1200).should == true
    (n == 0x12FF).should == true
    (n == 0x13FF).should == false
    (n == 0x11234).should == false

    (n == x(:h16_12XX)).should == true
    (n == x(:h16_123X)).should == true
    (n == x(:h16_133X)).should == false
  end
end
