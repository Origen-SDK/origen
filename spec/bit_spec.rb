require 'spec_helper'

# This module and double include below are required to give access to add_reg
# and similar methods from within the tests, but without adding the registers
# module to the global namespace which gives weird errors when the placeholder
# and other register objects pick up the top-level methods.
module RegTest

  include Origen::Registers

  describe Bit do

    include Origen::Registers

    def owner
      self
    end

    specify "reset value is assigned correctly" do
        Bit.new(self, 0).data.should == 0
        Bit.new(self, 0, res: 1).data.should == 1
    end

    specify "only LSB of reset value is stored" do
        Bit.new(self, 0, res: 0xFF).data.should == 1
    end

    it "can be written" do
        bit = Bit.new(self, 0).write(1)
        bit.data.should == 1
    end

    it "can be reset" do
        bit = Bit.new(self, 0).write(1)
        bit.reset
        bit.data.should == 0
        bit = Bit.new(self, 0, res: 1).write(0)
        bit.data.should == 0
        bit.reset
        bit.data.should == 1
    end

    specify "bit position is assigned correctly" do
        Bit.new(self, 0).position.should == 0
        Bit.new(self, 14).position.should == 14
    end

    it "can hold only one bit of data" do
        bit = Bit.new(self, 0)
        bit.write(0xFF)
        bit.data.should == 1
    end

    it "knows who it belongs to" do
        reg = Reg.new(self, 0x10, 16, :dummy)
        bit = Bit.new(reg, 0)
        bit.owner.should == reg
        bit.reset
        bit.owner.should == reg
    end

    it "returns the value required to write a given bit to a given value via the setting method" do
      class DUT
        include Origen::Registers
        attr_accessor :reg
        def initialize
          @reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0}, 
                                                b1: {pos: 4},
                                                b2: {pos: 9})
        end
      end
      reg = DUT.new.reg
        reg.bit(:b0).setting(1).should == 1
        reg.bit(:b0).setting(0xFF).should == 1
        reg.bit(:b0).setting(0xF0).should == 0
        reg.bit(:b1).setting(1).should == 0b10000
        reg.bit(:b1).setting(0).should == 0
        reg.bit(:b2).setting(1).should == 0x200
        reg.bit(:b2).setting(0).should == 0
    end

    it "returns the data shifted into position via the data_in_position method" do
        Bit.new(self, 0, res: 1).data_in_position.should == 0b1
        Bit.new(self, 3, res: 1).data_in_position.should == 0b1000
    end

    it "access codes can be assigned and queried" do
        b = Bit.new(self, 0)
        b.access.should == :rw
        b.rw?.should == true

        b = Bit.new(self, 0, access: :w1s)
        b.access.should == :w1s
        b.w1c?.should == false
        b.rw?.should == false
        b.w1s?.should == true

        b = Bit.new(self, 0, writable: false)
        b.access.should == :ro
        b.rw?.should == false
        b.ro?.should == true
    end
  end
end
