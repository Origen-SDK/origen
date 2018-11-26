require "spec_helper"

describe "Register bit order control" do

  class MSB0Dut
    include Origen::TopLevel

    def initialize
      @bit_order = :msb0

      add_reg :lsb0, 0, bit_order: :lsb0
      add_reg :msb0, 0x4
      add_reg :small_lsb0, 0x10, size: 4, bit_order: :lsb0
      add_reg :small_msb0, 0x20, size: 4

      sub_block :lsb0_sub_block, class_name: "LSB0SubBlock"
      sub_block :msb0_sub_block, class_name: "MSB0SubBlock"
      sub_block :lsb0_sub_block2, class_name: "MSB0SubBlock", bit_order: :lsb0
    end
  end

  class LSB0SubBlock
    include Origen::Model

    def initialize
      @bit_order = :lsb0

      add_reg :inherited_bit_order_reg, 0

      reg :SIUL2_MIDR1, 0x4, bit_order: :msb0  do |reg|
        bit 0..15,  :PARTNUM, res:0b0101011101110111
        bit 16,     :ED
        bit 17..21, :PKG
        bit 24..27, :MAJOR_MASK
        bit 28..31, :MINOR_MASK
      end
    end
  end

  class MSB0SubBlock
    include Origen::Model

    def initialize
      # Don't define bit_order here, the MSB0 should be inherited from the top-level

      add_reg :inherited_bit_order_reg, 0

      reg :SIUL2_MIDR1, 0x4, bit_order: :lsb0  do |reg|
        bit 0..15,  :PARTNUM, res:0b0101011101110111
        bit 16,     :ED
        bit 17..21, :PKG
        bit 24..27, :MAJOR_MASK
        bit 28..31, :MINOR_MASK
      end
    end
  end

  def msb0_reg
    dut.lsb0_sub_block.SIUL2_MIDR1
  end

  def lsb0_reg
    dut.msb0_sub_block.SIUL2_MIDR1
  end

  before :all do
    Origen.target.temporary = -> { MSB0Dut.new }
    Origen.target.load!
  end

  before :each do
    dut.reset
  end

  it "model-level bit order attribute can be set and read back" do
    dut.bit_order.should == :msb0
    dut.lsb0_sub_block.bit_order.should == :lsb0
    dut.lsb0_sub_block2.bit_order.should == :lsb0
  end

  it "model-level bit order attribute is inherited" do
    dut.msb0_sub_block.bit_order.should == :msb0
  end

  it "register-level bit order is inherited" do
    dut.lsb0_sub_block.inherited_bit_order_reg.bit_order.should == :lsb0
    dut.msb0_sub_block.inherited_bit_order_reg.bit_order.should == :msb0
  end

  it "register-level bit order can be overridden" do
    dut.lsb0_sub_block.SIUL2_MIDR1.bit_order.should == :msb0
  end

  it "bits inherit their parent register's bit order" do
    dut.lsb0_sub_block.SIUL2_MIDR1.MAJOR_MASK.bit_order.should == :msb0
    dut.lsb0_sub_block.SIUL2_MIDR1.MINOR_MASK.bit_order.should == :msb0
  end

  it "internally, bits are stored in the same order, where the array index matches the bit position" do
    dut.lsb0.map { |b| b.position }.should ==
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
    dut.msb0.map { |b| b.position }.should ==
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
  end

  it "registers return the same data value, regardless of bit order" do
    data = 0x11223344
    dut.lsb0.write(data)
    dut.lsb0.data.should == data
    dut.msb0.write(data)
    dut.msb0.data.should == data
  end

  it "Register shift out tests" do
    # Regular LSB0 reg, with all bits the same bit order
    data = 0x1122_3344
    dut.lsb0.write(data)
    dut.lsb0.data.should == data
    dut.lsb0.shift_out_right_with_index do |bit, i|
      bit.data.should == data[i]
    end
    dut.lsb0.shift_out_left_with_index do |bit, i|
      bit.data.should == data[31 - i]
    end
    # Regular MSB0 reg, with all bits the same bit order
    data = 0x1122_3344
    dut.msb0.write(data)
    dut.msb0.data.should == data
    # bit significance doesn not change with msb0, only the labeling of the bits
    # bits should come out in same order as lsb0 register
    dut.msb0.shift_out_right_with_index do |bit, i|
      bit.data.should == data[i]
    end
    dut.msb0.shift_out_left_with_index do |bit, i|
      bit.data.should == data[31 - i]
    end
  end

  it "Register level bit-access assigns data to the correct bit" do
    lsb0_reg.write(0x0001)
    lsb0_reg.data.should == 0x0001
    lsb0_reg[31].data.should == 0
    lsb0_reg[0].data.should == 1
    msb0_reg.write(0x0001)
    msb0_reg.data.should == 0x0001
    # with msb0, bit 31 of a 32 bit register is the least significant bit
    msb0_reg[31].data.should == 1
    # with msb0, bit 0 is always the most significant bit
    msb0_reg[0].data.should == 0
  end

  it "Bit level bit-access assigns data to the correct bit" do
    lsb0_reg.PKG.write(0x01)
    lsb0_reg.PKG.data.should == 1
    lsb0_reg.PKG[0].data.should == 1
    lsb0_reg.PKG[4].data.should == 0
    lsb0_reg[17].data.should == 1
    lsb0_reg[21].data.should == 0
    msb0_reg.PKG.write(0x01)
    msb0_reg.PKG.data.should == 1
    # for msb0, bit 0 is the MSB
    msb0_reg.PKG[0].data.should == 0
    msb0_reg.PKG[4].data.should == 1
    # for msb0, bit 17 (MSB of the field) is higher than bit 21
    msb0_reg[17].data.should == 0
    msb0_reg[21].data.should == 1
  end

  it "inverse and reverse data methods work with msb0 regs" do
    dut.msb0.write(0x00FF_AA55)
    dut.msb0.data.should == 0x00FF_AA55
    dut.msb0.data_b.should == 0xFF00_55AA
    dut.msb0.data_reverse.should == 0xAA55_FF00
  end
end
