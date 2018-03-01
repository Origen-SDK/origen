require "spec_helper"

class SoC_With_TestLimits
  include Origen::TopLevel
  
  # EDS == Electrical Data Sheet
  EDS_PIN_LKG_SPEC = 1.uA

  def initialize(options = {}) 
    add_power_domain :vddio do |d|
      d.description = '1.8V I/Os'
      d.nominal_voltage = 1.8.V
      d.maximum_voltage_rating = 2.50.V
      d.min = 1.62.V
      d.max = 1.98.V 
    end
    add_clock :core_clk do |c|
      c.description = 'Core clock'
      c.freq_target = 2.5.Ghz
      c.freq_range = 0.8.Ghz..3.2.Ghz
      c.users = [:core_complex]
      c.instantiate_users = false
    end  
    add_test :pin_leakage do |t|
      t.description = 'pin leakage, pin to GND and pin to RAIL'
      t.conditions  = [:minvdd, :maxvdd]
      t.platforms   = [:v93k]
    end.add_limits(:eds, min: (EDS_PIN_LKG_SPEC * -1), max: EDS_PIN_LKG_SPEC, )
    tests(:pin_leakage).add_limits(:ws, min: -100.nA, max: 100.nA)
    tests(:pin_leakage).add_limits(:ft, min: -500.nA, max: 500.nA)
    add_test :voh do |t|
      t.description = 'I/O voltage output high'
      t.conditions  = [:minvdd, :maxvdd]
      t.platforms   = [:v93k]
    end.add_limits(:eds, min: ":vddio * 0.7" )
    tests(:voh).add_limits(:ws, min: ":vddio * 0.55")
    tests(:voh).add_limits(:ft, min: ":eds - 10.mV")
    add_test :fmin do |t|
      t.description = 'Frequency Min'
      t.conditions  = [:minvdd, :maxvdd]
      t.platforms   = [:v93k]
    end.add_limits(:eds, min: :core_clk )
    tests(:fmin).add_limits(:ws, min: :eds)
    tests(:fmin).add_limits(:ft, min: ":eds + 50.Mhz")
  end
end

describe "Origen Limits" do

  before :each do
    Origen.app.unload_target!
    Origen.target.temporary = -> { SoC_With_TestLimits.new }
    Origen.load_target
  end

  after :all do
    Origen.app.unload_target!
  end
  
  it 'can add limits to an existing test' do
    dut.tests.size.should == 3
    dut.tests(:pin_leakage).limits.class.should == Hash
    dut.tests(:pin_leakage).limits(:eds).min.value.should == -1.uA
    dut.tests(:pin_leakage).limits(:eds).min.value.should == dut.tests(:pin_leakage).limits(:eds).min.expr
    dut.tests(:pin_leakage).limits(:eds).max.value.should == 1.uA
    dut.tests(:pin_leakage).limits(:eds).max.value.should == dut.tests(:pin_leakage).limits(:eds).max.expr
    dut.tests(:pin_leakage).limits(:ws).min.value.should == -100.nA
    dut.tests(:pin_leakage).limits(:ws).min.value.should == dut.tests(:pin_leakage).limits(:ws).min.expr
    dut.tests(:pin_leakage).limits(:ws).max.value.should == 100.nA
    dut.tests(:pin_leakage).limits(:ws).max.value.should == dut.tests(:pin_leakage).limits(:ws).max.expr
    dut.tests(:pin_leakage).limits(:ft).min.value.should == -500.nA
    dut.tests(:pin_leakage).limits(:ft).min.value.should == dut.tests(:pin_leakage).limits(:ft).min.expr
    dut.tests(:pin_leakage).limits(:ft).max.value.should == 500.nA
    dut.tests(:pin_leakage).limits(:ft).max.value.should == dut.tests(:pin_leakage).limits(:ft).max.expr
  end
  
  it 'can reference a clock object in a limit expression' do
    dut.tests(:fmin).limits(:eds).min.expr.should == ":core_clk"
    dut.clocks(:core_clk).min.should == 0.8.Ghz
    dut.tests(:fmin).limits(:eds).min.value.should == dut.clocks(:core_clk).min
  end
  
  it 'can reference a power domain object in a limit expression' do
    dut.tests(:voh).limits(:eds).min.expr.should == ":vddio * 0.7"
    dut.power_domains(:vddio).min.should == 1.62.V
    dut.tests(:voh).limits(:eds).min.value.should == dut.power_domains(:vddio).min * 0.7
  end
  
  it 'can use references to another limit set in a limit expression' do
    dut.tests(:fmin).limits(:ws).min.value.should == dut.tests(:fmin).limits(:eds).min.value
    dut.tests(:fmin).limits(:ws).min.value.should == 0.8.Ghz
    dut.tests(:fmin).limits(:ft).min.value.should == dut.tests(:fmin).limits(:eds).min.value + 50.Mhz
    dut.tests(:fmin).limits(:ft).min.value.should == 0.8.Ghz + 50.Mhz
  end
    
end 
    
