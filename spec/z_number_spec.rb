require 'spec_helper'

describe 'ZNumbers' do
  def z(sym)
    Origen::ZNumber.new(sym)
  end

  it 'can be created' do
    n = z(:b4_1zzz)
    n.size.should == 4
    n.mask.should == 0b1000
    n.to_s.should == '0b1ZZZ'

    n = z(:b4_1Z)
    n.size.should == 4
    n.mask.should == 0b1110
    n.to_s.should == '0b001Z'
    n = z(:h16_5Z)
    n.size.should == 16
    n.mask.should == 0xFFF0
    n.to_s.should == '0x005Z'

    z(16).to_s.should == '0xZZZZ'
  end

  it "Z means 0 in bitwise OR operations" do
    n = z(:b4_01Z1)
    (n | 0b0101).should == 0b0101
    (n | 0b0111).should == 0b0111
    (n | 0b10111).should == 0b10111
    (n | 0b1111).should == 0b1111
    (n | 0b0100).should == 0b0101

    n = z(:h16_12ZZ)
    (n | 0x1234).should == 0x1234
    (n | 0x1200).should == 0x1200
    (n | 0x12FF).should == 0x12FF
    (n | 0x13FF).should == 0x13FF
    (n | 0x11034).should == 0x11234

    #(n == z(:h16_12ZZ)).should == true
    #(n == z(:h16_123Z)).should == true
    #(n == z(:h16_133Z)).should == false
  end

  it 'can be shifted' do
    n = z(:b4_01Z1)
    n.to_s.should == '0b01Z1'
    n.size.should == 4
    n <<= 2
    n.size.should == 6
    n.to_s.should == '0b01Z100'

  end
end
