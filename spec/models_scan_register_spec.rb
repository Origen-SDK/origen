require 'spec_helper'

describe 'The Origen Scan Register model' do
  class Block
    include Origen::Model

    def initialize
      sub_block :reg4, class_name: "Origen::Models::ScanRegister", size: 4
    end
  end

  it 'can be instantiated in a parent model' do
    b = Block.new
    b.reg4.is_a?(Origen::Models::ScanRegister).should == true
    b.reg4.parent.should == b
    b.reg4.size.should == 4
  end

  it 'can shift data in and out via a clock' do
    b = Block.new
    sr = b.reg4
    sr.so.data.should == 0
    sr.si.drive(1)
    sr.u.data.should == 0
    b.clock!
    sr.u.data.should == 0b1000
    sr.so.data.should == 0
    b.clock!
    b.clock!
    b.clock!
    sr.u.data.should == 0b1111
    sr.so.data.should == 1
  end

  it 'can capture data' do
    b = Block.new
    sr = b.reg4
    sr.si.drive(0)
    sr.c.drive(0b1010)
    sr.u.data.should == 0
    sr.mode = :capture
    b.clock!
    sr.u.data.should == 0b1010
    sr.mode = :shift
    sr.so.data.should == 0
    b.clock!
    sr.so.data.should == 1
    b.clock!
    sr.so.data.should == 0
    b.clock!
    sr.so.data.should == 1
    b.clock!
    sr.so.data.should == 0
    sr.u.data.should == 0b0000
  end

end
