require "spec_helper"

describe "Register bit order significance" do

  class BOS0Dut
    include Origen::TopLevel

    def initialize
      add_reg :lsb0, 0, bit_order: :lsb0, size: 32 do |r|
        r.bit 31..16, :high_word, res: 0xaaaa
        r.bit 15..0,  :low_word, res: 0
      end
      add_reg :msb0, 0x4, bit_order: :msb0, size: 32 do |r|
        r.bit 0..15,  :high_word, res: 0xaaaa
        r.bit 16..31, :low_word, res: 0
      end
      add_reg :msb0_2, 0x8, bit_order: msb0, size: 32 do |r|
        r.bit 31,     :bit0_in_lsb0
        r.bit 30,     :bit1_in_lsb0
        r.bit 29,     :bit2_in_lsb0
        r.bit 28,     :bit3_in_lsb0
        r.bit 27,     :bit4_in_lsb0
        r.bit 26,     :bit5_in_lsb0
        r.bit 25,     :bit6_in_lsb0
        r.bit 24,     :bit7_in_lsb0
      end
    end
  end

  before :all do
    Origen.target.temporary = -> { BOS0Dut.new }
    Origen.target.load!
  end

  before :each do
    dut.reset
  end

  it "bit significance is maintained" do
    dut.lsb0.data.should == 0xaaaa_0000
    dut.msb0.data.should == 0xaaaa_0000
  end

  it "copy_all maintains bit significance" do
    dut.msb0.low_word.write 0x5555
    dut.lsb0.copy_all(dut.msb0)
    dut.lsb0.high_word.data.should == 0xaaaa
    dut.lsb0.low_word.data.should == 0x5555
    
    dut.msb0_2.bit0_in_lsb0.write 1
    dut.lsb0.copy_all(dut.msb0_2)
    dut.lsb0.data.should == 1
  end
end
