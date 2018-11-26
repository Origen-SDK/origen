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
  end
end
