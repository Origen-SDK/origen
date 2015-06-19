require "spec_helper"

# Some dummy classes to test out the specs module
class SoC_With_Specs
  include RGen::TopLevel

  def initialize
    sub_block :ip_with_specs, class_name: "IP_With_Specs", base_address: 0x1000_0000
    sub_block :ip_without_specs, class_name: "IP_WithOut_Specs", base_address: 0xDEAD_BEEF
    add_mode :default, description: "Nominal power/performance binned device"
    add_mode :low_power, description: "Low power binned device"
    add_mode :high_performance, description: "High performance binned device"
    modes.each do |mode|
      case mode
      when :default
        vdd_nom = 1.0.V
      when :low_power
        vdd_nom = 0.95.V
      when :high_performance
        vdd_nom = 1.05.V
      end
      spec :soc_vdd, :dc, mode  do
        symbol "Vdd"
        description "Soc Core Power Supply"
        min "#{vdd_nom} - 50.mV"
        max "#{vdd_nom} + 50.mV"
        unit "V"
        audience :external
      end
    end
    spec :soc_io_vdd, :dc do
      symbol "GVdd"
      description "Soc IO Power Supply"
      min 1.35.v
      max "1.50.v + 150.mv"
      unit "V"
      audience :external
    end
    spec :soc_pll_vdd, :dc do
      symbol "AVdd"
      description "Soc PLL Power Supply"
      min :soc_vdd
      max :soc_vdd
      unit "V"
      audience :external
    end
    spec :sysclk, :ac do
      description "Soc system input clock"
      min 10.Mhz
      max 133.Mhz
      unit "Hz"
      audience :external
    end
    spec :junction_temperature, :temperature do
      description "Typical Junction Temperature"
      typ '25 +/- 3'
      unit "\u00B0C".encode
      audience :external
    end
    add_mode :no_specs_defined
  end
end

class IP_With_Specs
  include RGen::Model
  def initialize
    spec :ip_setup_time, :ac do
      min 240.ps
      audience :internal
    end
  end
end

class IP_WithOut_Specs
  include RGen::Model
  def initialize
  end
end
describe "RGen Specs Module" do

  before :all do
    @dut = SoC_With_Specs.new
    @ip = @dut.ip_with_specs
  end

  it "can see top level specs" do
    @dut.specs.class.should == Array
    @dut.specs.size.should == 7
    @dut.modes.should == [:default, :low_power, :high_performance, :no_specs_defined]
    @dut.mode = :no_specs_defined
    @dut.specs(:soc_vdd).should == nil # Returns nil because @dut.mode is set to :no_specs_defined
    @dut.mode = :low_power
    @dut.specs(:soc_vdd).class.should == RGen::Specs::Spec # If only one spec is found then return the spec object instead of a hash
    # Add a spec note
    @dut.specs(:soc_vdd).add_note(:my_note, text: "This spec does not meet current power requirements")
    @dut.specs(:soc_vdd).notes.class.should == Hash
    @dut.specs(:soc_vdd).notes.size.should == 1
    @dut.specs(:soc_vdd).notes[:my_note].text.should == "This spec does not meet current power requirements"
    @dut.has_specs?.should == true
    @dut.ip_with_specs.has_specs?.should == true
    @dut.ip_without_specs.has_specs?.should == false
    @dut.has_spec?(:soc_vdd).should == true
    @dut.has_spec?(:soc_vddddddd).should == false
    @dut.specs(:soc_vdd).min.exp.should == "0.95 - 50.mV"
    @dut.specs(:soc_vdd).min.value.should == 0.9
    @dut.specs(:soc_vdd).limit_type.should == :double_sided
    @dut.specs(:soc_vdd).audience.should == :external
    @dut.specs(:soc_vdd).mode.should == :low_power
    @dut.specs(:soc_vdd).testable.should == nil
    @dut.mode = :high_performance
    @dut.specs(:soc_vdd).min.exp.should == "1.05 - 50.mV"
    @dut.specs(:soc_vdd).min.value.should == 1.0
    @dut.specs(:soc_vdd).mode.should == :high_performance
    @dut.specs.include?(:ip_setup_time).should == false
    @dut.specs(:soc_vdd).description.should == "Soc Core Power Supply"
    @dut.has_spec?(:soc_io_vdd).should == true # Returns true because even though this spec is not defined in mode :high_performance the spec does exist in the IP scope
    @dut.specs(:soc_io_vdd).mode.should == :global
    @dut.specs(:soc_io_vdd).max.exp.should == "1.50.v + 150.mv"
    @dut.specs(:soc_io_vdd).max.value.should == 1.65
    @dut.mode = nil
    @dut.has_spec?(:soc_vdd).should == true # mode is nil which means find all modes
    @dut.specs(:soc_vdd).size.should == 3 #
    @dut.has_spec?(:soc_vdd, mode: :default).should == true
  end

  it "can see sub_block specs" do
    @ip.modes.should == []
    @ip.specs(:soc_vdd).should == nil
    @ip.specs(:ip_setup_time).min.exp.should == 2.4e-10
    @ip.specs(:ip_setup_time).min.value.should == 2.4e-10
    @ip.specs(:ip_setup_time).limit_type.should == :single_sided
    @ip.specs(:ip_setup_time).audience.should == :internal
    @ip.specs(:ip_setup_time).mode.should == :local
    @ip.specs(:ip_setup_time).testable.should == nil
    @ip.add_mode :ensure_new_modes_dont_break_local_specs
    @ip.mode = :ensure_new_modes_dont_break_local_specs
    @ip.specs(:ip_setup_time).min.exp.should == 2.4e-10
    @ip.add_mode :new_mode_with_altered_specs
    @ip.mode = :new_mode_with_altered_specs
    @ip.spec :ip_setup_time, :ac do
      min 270.ps
      max 300.ps
      unit 'pS'
      audience :internal
      description "IP Setup Time with Double-Sided Limits"
    end
    @ip.specs(:ip_setup_time).class.should == RGen::Specs::Spec # Find 1 spec here because the IP set a specific mode so don't return global or local specs
    @ip.specs(:ip_setup_time).min.value.should == 2.7e-10
    @ip.specs(:ip_setup_time).max.value.should == 3.0e-10
    @ip.specs(:ip_setup_time).description.should == "IP Setup Time with Double-Sided Limits"
    @ip.specs(:ip_setup_time).limit_type.should == :double_sided
  end
end
