require "spec_helper"

# Some dummy classes to test out register and pin proxies

class TopLevel
  include RGen::TopLevel
  attr_reader :last_write, :last_read
  attr_reader :sub
  def initialize
    add_pin :tdo
  end
  def write_register(reg, options={})
    @last_write = reg.name
  end
  def read_register(reg, options={})
    @last_read = reg.name
  end

  def read_memory(reg, options={})
    @last_read = "#{reg.name} (mem)"
  end
end

class TopLevel1 < TopLevel
  def initialize
    super
    @sub = Subordinate1.new(self)
  end
end

class TopLevel2 < TopLevel
  include RGen::Callbacks  # Make sure this doesn't break the TopLevel callback
  def initialize
    super
    @sub = Subordinate2.new
  end
end

class Subordinate
  include RGen::Registers
  include RGen::Pins
  def initialize(*args)
    add_reg :reg1, 0, 8, data: {bits: 8}
  end
  def tdo
    pin(:tdo)
  end
end

class Subordinate1 < Subordinate
  attr_reader :owner
  def initialize(*args)
    super
    @owner = args.first
  end 
end

class Subordinate2 < Subordinate
end

describe "Register and Pin proxies" do

  # Since we are not loading a target this cleans out pin maps
  # and similar between each test
  before :each do
    RGen.app.unload_target!
  end

  it "should proxy register requests to 'owner' if available" do
    dut = TopLevel1.new
    dut.sub.reg(:reg1).write!(0x55)
    dut.last_write.should == :reg1
    dut.sub.reg(:reg1).read!
    dut.last_read.should == :reg1
  end

  it "should proxy register requests to the top level if defined" do
    dut = TopLevel2.new
    dut.sub.reg(:reg1).write!(0x55)
    dut.last_write.should == :reg1
    dut.sub.reg(:reg1).read!
    dut.last_read.should == :reg1
  end

  it "should proxy pin requests to 'owner' if available" do
    dut = TopLevel1.new
    # The test is just making sure this doesn't raise an error
    dut.sub.tdo.drive(1)
  end

  it "should proxy pin requests to the top level if defined" do
    dut = TopLevel2.new
    # The test is just making sure this doesn't raise an error
    dut.sub.tdo.drive(1)
  end

  it "read/write_memory is an alias for register" do
    TopLevel2.new
    reg = $dut.sub.reg1
    $dut.last_write.should_not == :reg1
    $dut.write_memory(reg)
    $dut.last_write.should == :reg1
    $dut.last_read.should_not == :reg1
    $dut.read_memory(reg)
    $dut.last_read.should == "reg1 (mem)"
  end
end
