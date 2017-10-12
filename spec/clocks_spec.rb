require "spec_helper"

# Some dummy classes to test out the Origen::Clocks module
class SoC_With_Clocks
  include Origen::TopLevel
  def initialize_clocks
    add_clock :cclk do |c|
      c.description = 'Core complex clock'
      c.nominal_frequency = 2.5.Ghz
      c.frequency_range = 0.8.Ghz..3.2.Ghz
      c.users = [:core_complex]
    end
    add_clock :ddrclk do |c|
      c.description = 'DDR clock'
      c.nominal_frequency = 2.0.Ghz
      c.frequency_range = 1.2.Ghz..2.8.Ghz
      c.users = [:ddr1, :ddr2]
    end
    add_clock :socclk do |c|
      c.description = 'SoC clock'
      c.nominal_frequency = 1.2.Ghz
      c.frequency_range = :fixed
      c.users = [:data_mesh]
    end
  end
  
end

describe "Clocks" do

  before :each do
    Origen.app.unload_target!
    Origen.target.temporary = -> { SoC_With_Clocks.new }
    Origen.load_target
  end
  
  after :all do
    Origen.app.unload_target!
  end

  it "can create and interact with clocks" do
    dut.sub_blocks.should == {}
    dut.initialize_clocks
    dut.sub_blocks.ids.should == ['core_complex', 'ddr1', 'ddr2', 'data_mesh']
    dut.clocks.keys.should == [:cclk, :ddrclk, :socclk]
    dut.clocks.size.should == 3
    dut.clocks.size.should == 3
    dut.clocks(:cclk).description.should == 'Core complex clock'
    dut.clocks(:cclk).nom.should == 2.5.Ghz
    dut.clocks(:cclk).range.should == (0.8.Ghz..3.2.Ghz)
    dut.clocks(:cclk).setpoint.should == nil
    dut.clocks(:cclk).users.should == [:core_complex]
    dut.clocks(:ddrclk).setpoint.should == nil
    dut.clocks(:socclk).setpoint.should == nil
    dut.clocks(:socclk).nominal_frequency.should == 1.2.Ghz
    dut.clocks(:socclk).setpoint_to_nominal
    dut.clocks(:socclk).setpoint.should == 1.2.Ghz
    dut.clocks(:cclk).setpoint = 2.7.Ghz
    dut.clocks(:cclk).setpoint_ok?.should == true
    dut.clocks(:cclk).setpoint = 0.6.Ghz
    dut.clocks(:cclk).setpoint_ok?.should == false
    dut.clocks(/clk/).class.should == Hash
    dut.clocks(:ddrclk).setpoint = 1.6.Ghz
    dut.clocks(:socclk).setpoint = 800.Mhz
    dut.clocks.inspect
  end

end
