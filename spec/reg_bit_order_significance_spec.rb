require "spec_helper"

describe "Register bit order significance" do

  class BOS0Dut
    include Origen::TopLevel

    def initialize
      add_reg :lsb0_reg, 0, bit_order: :lsb0, size: 32 do |r|
        r.bit 31..16, :high_word, res: 0xaaaa
        r.bit 15..0,  :low_word, res: 0
      end
      add_reg :msb0_reg, 0x4, bit_order: :msb0, size: 32 do |r|
        r.bit 0..15,  :high_word, res: 0xaaaa
        r.bit 16..31, :low_word, res: 0
      end
      add_reg :msb0_2, 0x8, bit_order: :msb0, size: 32 do |r|
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
    dut.lsb0_reg.data.should == 0xaaaa_0000
    dut.msb0_reg.data.should == 0xaaaa_0000

    dut.msb0_2.bit0_in_lsb0.write 1
    dut.msb0_2.data.should == 1

    dut.msb0_2[1].write 1
    dut.msb0_2.data.should == 3

    dut.lsb0_reg.read 0xfedc_9876
    dut.lsb0_reg.data.should == 0xfedc_9876
    dut.msb0_reg.with_msb0.bits(0..31).read 0x1234_5678
    dut.msb0_reg.data.should == 0x1234_5678
    dut.msb0_reg.with_msb0.bits(0..31).data.should == 0x1234_5678
  end

  it "copy_all maintains bit significance" do
    dut.msb0_reg.low_word.write 0x5555
    dut.lsb0_reg.copy_all(dut.msb0_reg)
    dut.lsb0_reg.high_word.data.should == 0xaaaa
    dut.lsb0_reg.low_word.data.should == 0x5555

    dut.msb0_2.bit0_in_lsb0.write 1
    dut.lsb0_reg.copy_all(dut.msb0_2)
    dut.lsb0_reg.data.should == 1
  end

  it "handles access using msb0 bit numbering" do
    dut.msb0_reg.write 0
    dut.msb0_reg.with_msb0[0..3].write 7
    dut.msb0_reg.data.should == 0x7000_0000

    dut.msb0_reg.with_msb0.high_word[0..3].write 3
    dut.msb0_reg.data.should == 0x3000_0000

    dut.msb0_reg.with_msb0.high_word[2..5].write 0xf
    dut.msb0_reg.data.should == 0x3c00_0000

    dut.reg(:msb0_reg).with_msb0.bits(:low_word).bits(0..2).write 3
    dut.msb0_reg.data.should == 0x3c00_6000
  end

  it "handles explicit lsb0 numbering" do
    dut.msb0_reg.write 0
    dut.msb0_reg.with_lsb0[3..0].write 7
    dut.msb0_reg.data.should == 7

    dut.msb0_reg.low_word.with_msb0[8..15].with_lsb0[3..0].write 1
    dut.msb0_reg.data.should == 1
  end

  it "correctly handles bit number interpretation on bit collections" do
    dut.lsb0_reg.write 0
    dut.lsb0_reg.high_word.with_msb0[0..1].write 2
    dut.lsb0_reg.data.should == 0x8000_0000

    dut.lsb0_reg.high_word[15..14].write 1
    dut.lsb0_reg.data.should == 0x4000_0000
  end

  it "with_msb0 is not sticky" do
    dut.lsb0_reg.with_msb0.high_word.with_bit_order.should == :msb0
    dut.lsb0_reg.with_msb0.high_word.write 0
    dut.lsb0_reg.high_word.with_bit_order.should == :lsb0

    dut.lsb0_reg.high_word.with_msb0[0..2].with_bit_order.should == :msb0
    dut.lsb0_reg.high_word[0..2].with_bit_order.should == :lsb0
    dut.lsb0_reg.high_word[15..14].with_bit_order.should == :lsb0

    dut.msb0_reg.low_word.with_msb0[8..15].with_lsb0[3..0].with_bit_order.should == :lsb0
  end

  it "shift_out methods of bit_collection with_msb0 behave the same as with lsb0" do
    dut.lsb0_reg.write 0xabcd_9876
    shift_out = ''
    dut.lsb0_reg.with_msb0.bits(0..31).shift_out do |bit|
      shift_out = bit.data.to_s + shift_out
    end
    dut.lsb0_reg.data.should == shift_out.to_i(2)

    shift_out = ''
    index_counter = 0
    dut.lsb0_reg.with_msb0.bits(0..15).shift_out_with_index do |bit, index|
      shift_out = bit.data.to_s + shift_out
      index.should == index_counter
      index_counter += 1
    end
    dut.lsb0_reg.bits(31..16).data.should == shift_out.to_i(2)

    shift_out = ''
    dut.msb0_reg.write 0xabcd_9876
    dut.msb0_reg.with_msb0.bits(0..31).reverse_shift_out do |bit|
      shift_out = shift_out + bit.data.to_s
    end
    dut.msb0_reg.data.should == shift_out.to_i(2)

    shift_out = ''
    index_counter = 0
    dut.msb0_reg.with_lsb0.bits(31..16).reverse_shift_out_with_index do |bit, index|
      shift_out = shift_out + bit.data.to_s
      index.should == index_counter
      index_counter += 1
    end
    dut.msb0_reg.bits(31..16).data.should == shift_out.to_i(2)
  end

  it "shift_out_direction methods of bit_collection with_msb0 behave the same as with lsb0" do
    dut.lsb0_reg.write 0xabcd_9876
    shift_out = ''
    dut.lsb0_reg.with_msb0.bits(0..31).shift_out_right do |bit|
      shift_out = bit.data.to_s + shift_out
    end
    dut.lsb0_reg.data.should == shift_out.to_i(2)

    shift_out = ''
    index_counter = 0
    dut.lsb0_reg.with_msb0.bits(0..15).shift_out_right_with_index do |bit, index|
      shift_out = bit.data.to_s + shift_out
      index.should == index_counter
      index_counter += 1
    end
    dut.lsb0_reg.bits(31..16).data.should == shift_out.to_i(2)

    shift_out = ''
    dut.msb0_reg.write 0xabcd_9876
    dut.msb0_reg.with_msb0.bits(0..31).shift_out_left do |bit|
      shift_out = shift_out + bit.data.to_s
    end
    dut.msb0_reg.data.should == shift_out.to_i(2)

    shift_out = ''
    index_counter = 0
    dut.msb0_reg.bits(31..16).shift_out_left_with_index do |bit, index|
      shift_out = shift_out + bit.data.to_s
      index.should == index_counter
      index_counter += 1
    end
    dut.msb0_reg.bits(31..16).data.should == shift_out.to_i(2)
  end

  it "corner cases pass" do
    out_reg = Origen::Registers::Reg.dummy(16)
    out_reg.with_msb0.bits(0..15).copy_all(dut.msb0_reg.high_word)
    out_reg.data.should == 0xaaaa

    dut.msb0_reg.with_msb0.high_word.position.should == dut.msb0_reg.high_word.position

    dut.msb0_reg.with_msb0.high_word.setting(0xfa).should == dut.msb0_reg.high_word.setting(0xfa)
  end

end
