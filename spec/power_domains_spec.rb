require "spec_helper"

# Some dummy classes to test out the Powerdomains module
class SoC_With_Domains
  include Origen::TopLevel

  def initialize
    add_power_domain :vdd do |domain|
      domain.description = 'CPU'
      domain.nominal_voltage = 1.0.V
      domain.voltage_range = 0.7.V..1.1.V
    end
    add_power_domain :vdda do |domain|
      domain.description = 'PLL'
      domain.nominal_voltage = 1.2.V
      domain.voltage_range = 1.08.V..1.32.V
    end
    add_power_domain :vccsoc do |domain|
      domain.description = 'SoC'
      domain.nominal_voltage = 1.5.V
      domain.voltage_range = 1.35.V..1.65.V
    end
  end
  
end

describe "Power domains" do

  before :each do
    Origen.app.unload_target!
    Origen.target.temporary = -> { SoC_With_Domains.new }
    Origen.load_target
  end
  
  after :all do
    Origen.app.unload_target!
  end

  it "can create and interact with power domains" do
    dut.power_domains.should == [:vdd, :vdda, :vccsoc]
    dut.power_domains.size.should == 3
    dut.power_domains.size.should == 3
    dut.power_domains(:vdd).description.should == 'CPU'
    dut.power_domains(:vdd).nom.should == 1.0.V
    dut.power_domains(:vdd).range.should == (0.7.V..1.1.V)
    dut.power_domains(:vdd).setpoint = 1.0.V
    dut.power_domains(:vdd).setpoint_ok?.should == true
    dut.power_domains(:vdd).setpoint = 0.65.V
    dut.power_domains(:vdd).setpoint_ok?.should == false
    dut.power_domains(/^vdd/).class.should == Hash
    dut.power_domains(/^vdd/).keys.should == [:vdd,:vdda]
  end

end
