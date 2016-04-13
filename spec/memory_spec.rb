require "spec_helper"

describe "A model's memory" do

  class MemoryTop
    include Origen::TopLevel

    def initialize
      sub_block :sub, class_name: "MemorySub", base_address: 0x2000_0000
    end

    def write_register(reg, options={})
      $last_write = reg.address
    end
  end

  class MemorySub
    include Origen::Model

    def initialize
      sub_block :sub, class_name: "MemorySub2", base_address: 0x1000_0000
    end
  end

  class MemorySub2
    include Origen::Model
  end

  before :each do
    Origen.target.temporary = -> do
      $dut = MemoryTop.new
    end
    Origen.target.load!
  end

  it "instantiates 32-bit reg objects on the fly" do
    dut.mem(0x1000).size.should == 32
    dut.sub.mem(0x100).size.should == 32
  end

  it "the memory width can be set" do
    dut.memory_width = 8
    dut.mem(0x1000).size.should == 8
    dut.sub.mem(0x100).size.should == 8
  end

  it "the memory base address is that of its parent block" do
    dut.mem(0x1000).address.should == 0x1000
    dut.sub.mem(0x100).address.should == 0x2000_0100
    dut.sub.sub.mem(0x100).address.should == 0x3000_0100
  end

  it "there is only really one memory" do
    dut.sub.mem(0x100).write(0x1111_2222)
    dut.sub.mem(0x100).data.should == 0x1111_2222
    dut.mem(0x2000_0100).data.should == 0x1111_2222
  end

  it "can be written like a regular register" do
    dut.mem(0x4000_0100).write!(0x10)
    $last_write.should == 0x4000_0100
  end

  it "addressed accesses must be aligned" do
    -> { dut.mem(0x4000_0101) }.should raise_error
  end

end
