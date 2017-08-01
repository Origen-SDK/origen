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

  before :all do
    @soc = SoC_With_Fuses.new
    @soc_ip = @soc.ip_with_fuses
  end

  it "can create and interact with top level fuses" do
    @soc.fuses.size.should == 2
    @soc.fuses[:ff1].name.should == :ff1
    @soc.fuses[:ff1].start_addr.should == 0xDEADBEEF
    @soc.fuses[:ff1].size.should == 8
    @soc.fuses[:ff1].default_value.should == 0
    @soc.fuses[:ff1].reprogrammeable?.should == false
    @soc.fuses[:ff1].customer_visible?.should == true
    @soc.fuses[:ff2].name.should == :ff2
    @soc.fuses[:ff2].start_addr.should == 1024
    @soc.fuses[:ff2].size.should == 4
    @soc.fuses[:ff2].default_value.should == 1
    @soc.fuses[:ff2].reprogrammeable?.should == true
    @soc.fuses[:ff2].customer_visible?.should == false
  end
  
  it "can create and interact with IP level fuses" do
    @soc_ip.fuses.size.should == 1
    @soc_ip.fuses.include?(:ff2).should== false
    @soc_ip.fuses[:ff1].name.should == :ff1
    @soc_ip.fuses[:ff1].start_addr.should == 0x1000_0009
    @soc_ip.fuses[:ff1].size.should == 16
    @soc_ip.fuses[:ff1].default_value.should == 0
    @soc_ip.fuses[:ff1].reprogrammeable?.should == true
    @soc_ip.fuses[:ff1].customer_visible?.should == true
  end
    
end
