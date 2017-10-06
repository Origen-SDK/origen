require "spec_helper"

# Some dummy classes to test out the PowerSupplies module
class SoC_With_Supplies
  include Origen::TopLevel

  def initialize
    add_power_supply :vdd do |supply|
      supply.description = 'CPU'
    end
    add_power_supply :vdda do |supply|
      supply.description = 'PLL'
    end
    add_power_supply :vddsoc do |supply|
      supply.description = 'SoC'
    end
  end
  
end

describe "Power Supplies" do

  before :each do
    Origen.app.unload_target!
    Origen.target.temporary = -> { SoC_With_Supplies.new }
    Origen.load_target
  end
  
  after :all do
    Origen.app.unload_target!
  end

  it "can create and interact with power supplies" do
    dut.power_supplies.should == [:vdd, :vdda, :vddsoc]
    dut.power_supplies.size.should == 3
    dut.supplies.size.should == 3
    dut.supplies(:vdd).description.should == 'CPU'
    dut.supplies(:vdd).specs.size.should == 3
  end

end
