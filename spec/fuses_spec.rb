require "spec_helper"

# Some dummy classes to test out the fuses module
class SoC_With_Fuses
  include Origen::TopLevel

  def initialize
    sub_block :ip_with_fuses, class_name: "IP_With_Fuses", base_address: 0x1000_0000
    
    ff1_fuse_field_data = {
      reprogrammeable: false,
      default_value: 0,
      customer_visible: true
    }
    ff2_fuse_field_data = {
      reprogrammeable: true,
      default_value: 1
    }
    
    fuse_field :ff1, 0xDEADBEEF, 8, ff1_fuse_field_data
    fuse_field :ff2, 1024, 4, ff2_fuse_field_data
    
  end
  
end

class IP_With_Fuses
  include Origen::Model
  
  def initialize
    ff1_fuse_field_data = {
      state_after_reset: 0,
      customer_visible: true
    }
    
    fuse_field :ff1, "4'b1001", 16, ff1_fuse_field_data
    
  end
  
end
    
describe "Fuses" do

  before :each do
    Origen.app.unload_target!
    Origen.target.temporary = -> { SoC_With_Fuses.new }
    Origen.load_target
  end
  
  after :all do
    Origen.app.unload_target!
  end

  it "can create and interact with top level fuses" do
    dut.fuses.size.should == 2
    dut.fuses[:ff1].name.should == :ff1
    dut.fuses[:ff1].start_addr.should == 0xDEADBEEF
    dut.fuses[:ff1].size.should == 8
    dut.fuses[:ff1].default_value.should == 0
    dut.fuses[:ff1].reprogrammeable?.should == false
    dut.fuses[:ff1].customer_visible?.should == true
    dut.fuses[:ff2].name.should == :ff2
    dut.fuses[:ff2].start_addr.should == 1024
    dut.fuses[:ff2].size.should == 4
    dut.fuses[:ff2].default_value.should == 1
    dut.fuses[:ff2].reprogrammeable?.should == true
    dut.fuses[:ff2].customer_visible?.should == false
  end
  
  it "can create and interact with IP level fuses" do
    dut.ip_with_fuses.fuses.size.should == 1
    dut.ip_with_fuses.fuses.include?(:ff2).should== false
    dut.ip_with_fuses.fuses[:ff1].name.should == :ff1
    dut.ip_with_fuses.fuses[:ff1].start_addr.should == 0x1000_0009
    dut.ip_with_fuses.fuses[:ff1].size.should == 16
    dut.ip_with_fuses.fuses[:ff1].default_value.should == 0
    dut.ip_with_fuses.fuses[:ff1].reprogrammeable?.should == true
    dut.ip_with_fuses.fuses[:ff1].customer_visible?.should == true
  end
    
end
