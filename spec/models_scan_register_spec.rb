require 'spec_helper'

describe 'The Origen Scan Register model' do
  class Block
    include Origen::Model

    def initialize(options={})
      sub_block :reg4, class_name: "Origen::Models::ScanRegister", size: 4, reset: options[:reset]
    end
  end

  it 'can be instantiated in a parent model' do
    b = Block.new
    b.reg4.is_a?(Origen::Models::ScanRegister).should == true
    b.reg4.parent.should == b
    b.reg4.size.should == 4
  end

  it 'can shift data in and out via a clock when SE is high' do
    b = Block.new
    sr = b.reg4
    sr.so.data.should == 0
    sr.si.drive(1)
    sr.sr.data.should == 0
    b.clock!
    sr.sr.data.should == 0
    sr.se.drive(1)
    b.clock!
    sr.sr.data.should == 0b1000
    sr.so.data.should == 0
    b.clock!
    b.clock!
    b.clock!
    sr.sr.data.should == 0b1111
    sr.so.data.should == 1
    sr.si.drive(0)
    b.clock!
    sr.sr.data.should == 0b0111
    sr.se.drive(0)
    b.clock!
    b.clock!
    b.clock!
    sr.sr.data.should == 0b0111
  end

  it 'can capture data when CE is high' do
    b = Block.new(reset: 0b1111)
    sr = b.reg4
    sr.sr.data.should == 0b1111
    sr.si.drive(0)
    sr.c.drive(0b1010)
    sr.sr.data.should == 0b1111
    b.clock!
    sr.sr.data.should == 0b1111
    sr.ce.drive(1)
    b.clock!
    sr.sr.data.should == 0b1010
  end

  it 'can update data when UE is high' do
    b = Block.new(reset: 0b1010)
    sr = b.reg4
    sr.data.should == 0b1010

    sr.si.drive(1)
    sr.se.drive(1)
    b.clock!
    b.clock!
    b.clock!
    b.clock!

    sr.data.should == 0b1010
    sr.se.drive(0)
    sr.ue.drive(1)
    sr.data.should == 0b1010
    b.clock!
    sr.data.should == 0b1111
  end

  it "chained registers don't collapse at the join" do
    class ChainBlock
      include Origen::Model

      def initialize(options={})
        port :si
        port :so
        sub_block :reg1, class_name: "Origen::Models::ScanRegister", size: 4, reset: options[:reset]
        sub_block :reg2, class_name: "Origen::Models::ScanRegister", size: 4, reset: options[:reset]
        si.connect_to reg1.si
        reg1.so.connect_to reg2.si
        so.connect_to reg2.so
        reg1.se.drive(1)
        reg2.se.drive(1)
      end
    end
    b = ChainBlock.new
    b.si.drive(1)
    b.so.data.should == 0
    b.clock!
    b.so.data.should == 0
    b.clock!
    b.so.data.should == 0
    b.clock!
    b.so.data.should == 0
    b.clock!
    b.so.data.should == 0
    b.clock!
    b.so.data.should == 0
    b.clock!
    b.so.data.should == 0
    b.clock!
    b.so.data.should == 0
    b.clock!
    b.so.data.should == 1
  end
  

end
