require "spec_helper"

# Some dummy classes to test out the Powerdomains module
class SoC_With_Domains
  include Origen::TopLevel
  
  VDD_SIGNAL_PINS = [:pin1, :pin2, :pin3]
  VDD_POWER_PINS = [:vdd1, :vdd2, :vdd3]
  VDD_GND_PINS = [:vss1, :vss2, :vss3]

  def initialize
    VDD_SIGNAL_PINS.each do |p|
      $dut.add_pin p do |pin|
        pin.supply = :vdd
      end
    end
    VDD_POWER_PINS.each do |p|
      $dut.add_power_pin p do |pin|
        pin.supply = :vdd
      end
    end
    VDD_GND_PINS.each do |p|
      $dut.add_ground_pin p do |pin|
        pin.supply = :vdd
      end
    end
    add_power_domain :vdd do |domain|
      domain.description = 'CPU'
      domain.nominal_voltage = 1.0.V
      domain.unit_voltage_range = 0.7.V..1.1.V
      domain.maximum_voltage_rating = 1.50.V
      domain.min = 0.9.V
      domain.max = 1.1.V
      domain.display_names(Nokogiri::XML::DocumentFragment.parse 'OV<sub>DD</sub>')
    end
    add_power_domain :vdda do |domain|
      domain.description = 'PLL'
      domain.nominal_voltage = 1.2.V
      domain.unit_voltage_range = 1.08.V..1.32.V
      domain.maximum_voltage_rating = 1.80.V
      domain.display_names(Nokogiri::XML::DocumentFragment.parse 'AV<sub>DD</sub>')
    end
    add_power_domain :vccsoc do |domain|
      domain.description = 'SoC'
      domain.nominal_voltage = 1.5.V
      domain.display_names(Nokogiri::XML::DocumentFragment.parse 'VDD')
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
    dut.power_domains.keys.should == [:vdd, :vdda, :vccsoc]
    dut.power_domains.size.should == 3
    dut.power_domains(:vdd).description.should == 'CPU'
    dut.power_domains(:vdd).nom.should == 1.0.V
    dut.power_domains(:vdd).unit_voltage_range.should == (0.7.V..1.1.V)
    dut.power_domains(:vdd).setpoint.should == nil
    dut.power_domains(:vdda).setpoint.should == nil
    dut.power_domains(:vccsoc).unit_voltage_range.should == :fixed
    dut.power_domains(:vccsoc).setpoint.should == nil
    dut.power_domains(:vccsoc).nominal_voltage.should == 1.5.V
    dut.power_domains(:vccsoc).setpoint_to_nominal
    dut.power_domains(:vccsoc).setpoint.should == 1.5.V
    dut.power_domains(:vdd).setpoint = 1.0.V
    dut.power_domains(:vdd).setpoint_ok?.should == true
    dut.power_domains(:vdd).setpoint = 1.65.V
    dut.power_domains(:vdd).setpoint_ok?.should == false
    dut.power_domains(/^vdd/).class.should == Hash
    dut.power_domains(/^vdd/).keys.should == [:vdd,:vdda]
    dut.power_domains(:vdda).setpoint = 1.1.V
    dut.power_domains(:vccsoc).setpoint = 1.35.V
    dut.power_domains.inspect
  end
  
  it "can find pins that reference itself" do
    dut.power_domains(:vdd).signal_pins.should == [:pin1, :pin2, :pin3]
    dut.power_domains(:vdd).power_pins.should == [:vdd1, :vdd2, :vdd3]
    dut.power_domains(:vdd).ground_pins.should == [:vss1, :vss2, :vss3]
    dut.power_domains(:vdd).has_pin?(:vdd1).should == true
    dut.power_domains(:vdd).pin_type(:vdd1).should == :power
    dut.power_domains(:vdd).has_power_pin?(:vdd1).should == true
    dut.power_domains(:vdd).has_pin?(:pin1).should == true
    dut.power_domains(:vdd).pin_type(:pin1).should == :signal
    dut.power_domains(:vdd).has_signal_pin?(:pin1).should == true
    dut.power_domains(:vdd).has_pin?(:vss1).should == true
    dut.power_domains(:vdd).pin_type(:vss1).should == :ground
    dut.power_domains(:vdd).has_ground_pin?(:vss1).should == true
    dut.power_domains(:vdda).signal_pins.should == []
    dut.power_domains(:vdda).power_pins.should == []
    dut.power_domains(:vdda).ground_pins.should == []
    dut.power_domains(:vdda).has_pin?(:vdd1).should == false
  end
  
  it 'Display Names are correct' do
    dut.power_domains(:vdd).display_name[:default].to_xml.should == 'OV<sub>DD</sub>'
    dut.power_domains(:vdd).display_name[:input].to_xml.should == 'OV<sub>IN</sub>'
    dut.power_domains(:vdd).display_name[:output].to_xml.should == 'OV<sub>OUT</sub>'
    dut.power_domains(:vdda).display_name[:default].to_xml.should == 'AV<sub>DD</sub>'
    dut.power_domains(:vdda).display_name[:input].to_xml.should == 'AV<sub>IN</sub>'
    dut.power_domains(:vdda).display_name[:output].to_xml.should == 'AV<sub>OUT</sub>'
    dut.power_domains(:vccsoc).display_name[:default].to_xml.should == 'VDD'
    dut.power_domains(:vccsoc).display_name[:input].to_xml.should == 'VDD'
    dut.power_domains(:vccsoc).display_name[:output].to_xml.should == 'VDD'    
  end
  
  it 'Properly creates the top level DUT spec for the power supply' do
    dut.power_domains(:vdd).min.should == 0.9.V
    dut.power_domains(:vdd).nominal_voltage.should == 1.0.V
    dut.power_domains(:vdd).max.should == 1.1.V
    dut.specs(:vdd).min.value.should == 0.9.V
    dut.specs(:vdd).typ.value.should == 1.0.V
    dut.specs(:vdd).max.value.should == 1.1.V
  end

end
