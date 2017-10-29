require "spec_helper"

# Some dummy classes to test out the specs module
class SoC_With_Specs
  include Origen::TopLevel

  def initialize
    add_clock :core_clk do |c|
      c.users =           [:cores]
      c.freq_target =     1.2.Ghz
      c.freq_range =      1.0.Ghz..1.4.Ghz
    end
    add_power_domain :vmemio do |d|
      d.description = 'Memory IO Power Domain'
      d.nominal_voltage = 1.35.V
    end
    add_power_domain :voffset do |d|
      d.description = 'Fake power supply that is used for spec testing'
      d.nominal_voltage = 0.25.V
    end
    sub_block :ip_with_specs, class_name: "IP_With_Specs", base_address: 0x1000_0000
    sub_block :ip_without_specs, class_name: "IP_WithOut_Specs", base_address: 0xDEAD_BEEF
    add_mode :default, description: "Nominal power/performance binned device"
    add_mode :low_power, description: "Low power binned device"
    add_mode :high_performance, description: "High performance binned device"
    spec :fmin, :ac do |s|
      s.symbol "Fmin"
      s.description = "Frequency Min"
      s.min = ":core_clk * 0.9"
    end
    spec :memio_voh, :dc do |s|
      s.symbol "Voh"
      s.description = "Output high voltage"
      s.max = ":vmemio * 0.8"
    end
    spec :direct_ref_spec, :dc do |s|
      s.symbol "DirectRefSpec"
      s.description = "Check for the case where a spec formula references a Symbol"
      s.max = :vmemio
    end
    spec :memio_voh_offset, :dc do |s|
      s.symbol "Voh_offset"
      s.description = "Output high voltage with offset"
      s.max = ":vmemio * 0.8 - :voffset"
    end
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
    spec :tnikhov2, :ac do
      unit "nc"
      max 3.5
      audience :external
    end
    add_mode :no_specs_defined
  end
end

class IP_With_Specs
  include Origen::Model
  def initialize
    spec :ip_setup_time, :ac do
      min 240.ps
      audience :internal
    end
    note(:note1, :spec, {mode: :default, audience: :external, text: 'Note 1', markup: 'Not<sub>e</sub> 1', internal_comment: 'Reason for note'})
    note(:note2, :spec, {mode: :default, audience: :external, text: 'Note 2', markup: 'Not<sub>e</sub> 2', internal_comment: 'Reason for note'})
    note(:note3, :spec, {mode: :low_power, audience: :external, text: 'Note 3', markup: 'Not<sub>e</sub> 3', internal_comment: 'Reason for note'})
    note(:note4, :spec, {mode: :low_power, audience: :internal, text: 'Note 4', markup: 'Not<sub>e</sub> 4', internal_comment: 'Reason for note'})
    note(:note5, :spec, {mode: :high_performance, audience: :internal, text: 'Note 5', markup: 'Not<sub>e</sub> 5', internal_comment: 'Reason for note'})
    note(:note6, :spec, {mode: :high_performance, audience: :external, text: 'Note 6', markup: 'Not<sub>e</sub> 6', internal_comment: 'Reason for note'})
    note(:note6, :doc, {mode: :high_performance, audience: :external, text: 'Note 6', markup: 'Not<sub>e</sub> 6', internal_comment: 'Reason for note'})
    note(:note6, :mode, {mode: :high_performance, audience: :external, text: 'Note 6', markup: 'Not<sub>e</sub> 6', internal_comment: 'Reason for note'})
    note(:note6, :feature, {mode: :high_performance, audience: :external, text: 'Note 6', markup: 'Not<sub>e</sub> 6', internal_comment: 'Reason for note'})
    note(:note6, :sighting, {mode: :high_performance, audience: :external, text: 'Note 6', markup: 'Not<sub>e</sub> 6', internal_comment: 'Reason for note'})
    note(:note7, :spec, {mode: :high_performance, audience: :external, text: 'Note 7', markup: 'Not<sub>e</sub> 7', internal_comment: 'Reason for note'})
    note(:note7, :doc, {mode: :high_performance, audience: :external, text: 'Note 7', markup: 'Not<sub>e</sub> 7', internal_comment: 'Reason for note'})
    note(:note7, :mode, {mode: :high_performance, audience: :external, text: 'Note 7', markup: 'Not<sub>e</sub> 7', internal_comment: 'Reason for note'})
    note(:note7, :feature, {mode: :high_performance, audience: :external, text: 'Note 7', markup: 'Not<sub>e</sub> 7', internal_comment: 'Reason for note'})
    note(:note7, :sighting, {mode: :high_performance, audience: :external, text: 'Note 7', markup: 'Not<sub>e</sub> 7', internal_comment: 'Reason for note'})
    spec_feature(:feature1, {type: :intro, audience: :external}, :devicea, 'Feature 1', 'Internal Comment 1')
    spec_feature(:feature2, {type: :intro, audience: :internal}, :deviceb, 'Feature 2', 'Internal Comment 2')
    spec_feature(:feature3, {type: :feature, audience: :internal}, :devicea, 'Feature 3', nil)
    spec_feature(:feature3, {type: :feature, audience: :external}, :deviceb, 'Feature 3', nil)
    spec_feature(:feature4, {type: :subfeature, audience: :external, feature_ref: :feature3}, :devicea, 'Feature 3, subfeature 4', nil)
    spec_feature(:feature4, {type: :subfeature, audience: :external, feature_ref: :feature3}, :deviceb, 'Feature 3, subfeature 4', nil)
    spec_feature(:feature5, {type: :subfeature, audience: :external, feature_ref: :feature3}, :devicea, 'Feature 3, subfeature 5', nil)
    spec_feature(:feature5, {type: :subfeature, audience: :external, feature_ref: :feature3}, :deviceb, 'Feature 3, subfeature 5', nil)
    spec_feature(:feature6, {type: :subfeature, audience: :external, feature_ref: :feature3}, :devicea, 'Feature 3, subfeature 6', nil)
    spec_feature(:feature6, {type: :subfeature, audience: :external, feature_ref: :feature3}, :deviceb, 'Feature 3, subfeature 6', nil)
    exhibit(:exhibit1, :fig, {}, {title: 'Exhibit 1', description: 'Exhibit 1 Description', reference: 'link1', markup: 'markup', block_id: :esdhc})
    exhibit(:exhibit2, :fig, {}, {title: 'Exhibit 2', description: 'Exhibit 2 Description', reference: 'link2', markup: 'markup', block_id: :esdhc})
    exhibit(:exhibit3, :fig, {}, {title: 'Exhibit 3', description: 'Exhibit 3 Description', reference: 'link3', markup: 'markup', block_id: :ddr})
    exhibit(:exhibit4, :table, {}, {title: 'Exhibit 4', description: 'Exhibit 4 Description', reference: 'link4', markup: 'markup', block_id: :esdhc})
    exhibit(:exhibit5, :table, {}, {title: 'Exhibit 5', description: 'Exhibit 5 Description', reference: 'link5', markup: 'markup', block_id: :ddr})
    exhibit(:exhibit1_ovr, :fig, {}, {title: 'Exhibit 1 Override', description: 'Exhibit 1 Override Description', reference: 'link1_ovr', markup: 'markup', block_id: :esdhc})
    exhibit(:exhibit4_ovr, :table, {}, {title: 'Exhibit 4 Override', description: 'Exhibit 4 Override Description', reference: 'link4_ovr', markup: 'markup', block_id: :ddr})
    version_history('March 1, 2015', 'John Doe', 'Initial checkin.  Something here about what was added')
    version_history('April 15, 2015', 'Jane Doe', 'Made this better by doing one, two, three things.')
    version_history('May 30, 2015', 'Jim Bob', 'Review with Subject Matter Experts.')
    version_history('October 1, 2016', 'Sue Bird', {internal: 'Change with internal comments', external: 'For external customers'}, 'label.01.02.03', false)
    doc_resource({mode: :default, type: :ac, sub_type: 'input', audience: :external}, {title: 'Title for Table 1', note_refs: :note1, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :low_power, type: :ac, sub_type: 'input', audience: :external}, {title: 'Title for Table 1', note_refs: [:note5, :note6], exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :high_performance, type: :ac, sub_type: 'input', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :default, type: :ac, sub_type: 'input', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: [:exhibit1, :exhibit5]}, {before: nil, after: nil}, {})
    doc_resource({mode: :low_power, type: :ac, sub_type: 'input', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :high_performance, type: :ac, sub_type: 'input', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :default, type: :ac, sub_type: 'output', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :low_power, type: :ac, sub_type: 'output', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :high_performance, type: :ac, sub_type: 'output', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :default, type: :ac, sub_type: 'output', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :low_power, type: :ac, sub_type: 'output', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :high_performance, type: :ac, sub_type: 'output', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :default, type: :ac, sub_type: 'output', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :default, type: :dc, sub_type: 'input', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :low_power, type: :dc, sub_type: 'input', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :high_performance, type: :dc, sub_type: 'input', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :default, type: :dc, sub_type: 'input', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :low_power, type: :dc, sub_type: 'input', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :high_performance, type: :dc, sub_type: 'input', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :default, type: :dc, sub_type: 'output', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :low_power, type: :dc, sub_type: 'output', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :high_performance, type: :dc, sub_type: 'output', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :default, type: :dc, sub_type: 'output', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :low_power, type: :dc, sub_type: 'output', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :high_performance, type: :dc, sub_type: 'output', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    doc_resource({mode: :default, type: :dc, sub_type: 'output', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    override({block: :esdhc, usage: true}, {spec_id: :vdd, mode_ref: :nominal, sub_type: 'input', audience: :external}, {min: 0.97}, {disable: false})
    override({block: :esdhc, usage: true}, {spec_id: :vdd_io, mode_ref: :nominal, sub_type: 'output', audience: :external}, {min: 0.97}, {disable: false})
    override({block: :esdhc, usage: true}, {spec_id: :vdd_lp, mode_ref: :low_power, sub_type: 'input', audience: :external}, {min: 0.97}, {disable: false})
    override({block: :i2c, usage: true}, {spec_id: :clk_rise, mode_ref: :high_performance, sub_type: 'input', audience: :external}, {min: 0.97}, {disable: true})
    override({block: :ddr, usage: true}, {spec_id: :vdd, mode_ref: :high_performance, sub_type: 'output', audience: :external}, {min: 0.97}, {disable: true})
    override({block: :ddr, usage: true}, {spec_id: :clk_fall, mode_ref: :nominal, sub_type: 'input', audience: :external}, {min: 0.97}, {disable: false})
    power_supply('GVDD', 'G1VDD')
    power_supply('GVDD', 'G2VDD')
    power_supply('DVDD', 'D1VDD')
    power_supply('DVDD', 'D2VDD')
    power_supply('DVDD', 'D3VDD')
    power_supply('XVDD', 'X1VDD')
    power_supply('XVDD', 'X2VDD')
    power_supply('XVDD', 'X3VDD')
    power_supply('XVDD', 'X4VDD')
    power_supply('XVDD', 'X5VDD')
    power_supply('XVDD', 'X6VDD')
    power_supply('SVDD', 'S1VDD')
    power_supply('SVDD', 'S2VDD')
    power_supply('SVDD', 'S3VDD')
    power_supply('SVDD', 'S4VDD')
    power_supply('SVDD', 'S5VDD')
    power_supply('SVDD', 'S6VDD')
    mode_select({name: :ddr, ds_header: 'DDR Controller', usage: true, location: 'path'}, {mode: :ddr_ddr4, supported: true}, {supply: 'G1VDD', voltage_level: '1.35V', use_diff: true})
    mode_select({name: :ddr, ds_header: 'DDR Controller', usage: true, location: 'path'}, {mode: :ddr_ddr3, supported: true}, {supply: 'G1VDD', voltage_level: '1.35V', use_diff: true})
    mode_select({name: :ifc1, ds_header: 'IFC', usage: true, location: 'path'}, {mode: :ifc1_nand, supported: true}, {supply: 'OVDD', voltage_level: '3.0V', use_diff: true})
    mode_select({name: :i2c1, ds_header: 'InterIntergrated Circuit', usage: true, location: 'path'}, {mode: :i2c_i2c, supported: true}, {supply: 'D1VDD', voltage_level: '5.0V', use_diff: true})
    creation_info('Jim Smith', '15 Feb 2015', '1.0', {source: 'block-ref-ddr', ip_block_name: :ddr, revision: 'a'}, {tool: 'ISC App', version: '0.7.5'})
    creation_info('Jim Smith', '22 Mar 2015', '1.0', {source: 'block-ref-i2c', ip_block_name: :i2c, revision: 'c'}, {tool: 'ISC App', version: '0.7.5'})
    creation_info('Jim Smith', '29 Apr 2015', '1.0', {source: 'block-ref-ifc', ip_block_name: :ifc, revision: 'g'}, {tool: 'ISC App', version: '0.7.5'})
    creation_info('Jim Smith', '4 Jun 2015', '1.0', {source: 'block-ref-esdhc', ip_block_name: :esdhc, revision: 'b'}, {tool: 'ISC App', version: '0.7.5'})
    documentation({level: 1, section: 'Section 1', subsection: nil}, {interface: 'SoC', type: nil, subtype: nil, mode: nil, audience: :external}, [:device1], nil)
    documentation({level: 3, section: 'Section 1', subsection: 'SubSection A'}, {interface: 'SoC', type: :dc, subtype: nil, mode: nil, audience: :external}, [:device1], 'http://link_to_section1a.xml')
    documentation({level: 4, section: 'Section 1', subsection: 'SubSection B'}, {interface: 'SoC', type: :supply, subtype: :abs_max_ratings, mode: nil, audience: :external}, [:device2], nil)
    documentation({level: 5, section: 'Section 2', subsection: 'SubSection A'}, {interface: 'Block A', type: :dc, subtype: :V3p3V, mode: nil, audience: :internal}, [:device1], nil)
    documentation({level: 8, section: 'Section 2', subsection: 'SubSection B'}, {interface: 'Block A', type: :supply, subtype: nil, mode: nil, audience: :external}, [:device1, :device2], 'http://link_to_section2b.xml')
    documentation({level: 6, section: 'Section 2', subsection: 'SubSection C'}, {interface: 'Block A', type: :power, subtype: nil, mode: nil, audience: :external}, [:device1, :device2], 'http://link_to_section2c.xml')
    documentation({level: 0, section: 'Section 2', subsection: 'SubSection D'}, {interface: 'Block A', type: :impedance, subtype: nil, mode: nil, audience: :external}, [:device1, :device2], 'http://link_to_section2d.xml')
    documentation({level: 1, section: 'Section 3', subsection: 'SubSection A'}, {interface: 'Block B', type: :ac, subtype: nil, mode: nil, audience: :external}, [:device1, :device2], nil)
    documentation({level: 2, section: 'Section 3', subsection: 'SubSection B'}, {interface: 'Block B', type: :dc, subtype: :V3p3V, mode: nil, audience: :internal}, [:device1, :device2], 'http://link_to_section3b.xml')
    documentation({level: 4, section: 'Section 3', subsection: 'SubSection C'}, {interface: 'Block B', type: :supply, subtype: nil, mode: nil, audience: :external}, [:device1, :device2], 'http://link_to_section3c.xml')    
  end
end

class IP_WithOut_Specs
  include Origen::Model
  def initialize
  end
end

def get_true_hash_size(hash, obj_class)
  size = 0
  return size if hash.nil?
  hash.each do |k, v|
    if v.is_a? Hash
      size += get_true_hash_size(v, obj_class)
    elsif v.is_a? Array
      v.each  do  |w|
        size += 1 if w.is_a? obj_class
      end
    elsif v.is_a? obj_class
      size += 1
    end
  end
  size
end

describe "Origen Specs Module" do

  before :all do
    @dut = SoC_With_Specs.new
    @ip = @dut.ip_with_specs
  end

  it "can see top level specs" do
    @dut.specs.size.should == 12
    @dut.modes.should == [:default, :low_power, :high_performance, :no_specs_defined]
    @dut.mode = :no_specs_defined
    @dut.specs(:soc_vdd).should == nil # Returns nil because @dut.mode is set to :no_specs_defined
    @dut.mode = :low_power
    @dut.specs(:soc_vdd).class.should == Origen::Specs::Spec # If only one spec is found then return the spec object instead of a hash
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

  it "multiple specs are returned in a SpecArray" do
    @dut.specs.class.should == Origen::Specs::SpecArray
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
    @ip.specs(:ip_setup_time).class.should == Origen::Specs::Spec # Find 1 spec here because the IP set a specific mode so don't return global or local specs
    @ip.specs(:ip_setup_time).min.value.should == 2.7e-10
    @ip.specs(:ip_setup_time).max.value.should == 3.0e-10
    @ip.specs(:ip_setup_time).description.should == "IP Setup Time with Double-Sided Limits"
    @ip.specs(:ip_setup_time).limit_type.should == :double_sided
    @ip.delete_all_specs
    @ip.spec :ip_setup_time, :ac do
      min 240.ps
      audience :internal
    end
    @ip.specs(:ip_setup_time).min.exp.should == 2.4e-10
    @ip.specs(:ip_setup_time).min.value.should == 2.4e-10
  end

  it "fuzzy finding with a regex works" do
    $dut.has_spec?("tnikhov").should == false  
    $dut.has_spec?(:tnikhov).should == false
    $dut.has_spec?(:tnikhov2).should == true
    $dut.has_spec?(/tnikhov/).should == true
  end

  it "finding specs via :symbol option works" do
    $dut.has_spec?(:gvdd, symbol: true).should == true  
    $dut.has_spec?(:dvdd, symbol: true).should == false  
  end
  
  it "can see sub_block features" do
    @ip.spec_features(id: :feature1).class.should == Origen::Specs::Spec_Features
    #@ip.spec_features(id: :feature3).size.class.should == 2
    @ip.spec_features(device: :devicea).size.should == 5
  end
  
  it "can see sub_block notes" do
   @ip.notes(id: :note1).class.should == Origen::Specs::Note 
   @ip.notes(type: :spec).size.should == 7
   @ip.delete_all_notes
   @ip.notes(type: :spec).should == nil
   @ip.note(:note1, :spec, {mode: :default, audience: :external, text: 'Note 1', markup: 'Not<sub>e</sub> 1', internal_comment: 'Reason for note'})
   @ip.notes(type: :spec).class.should == Origen::Specs::Note 
  end
  
  it "can see sub_block exhibits" do
    get_true_hash_size(@ip.exhibits, Origen::Specs::Exhibit).should == 7
    get_true_hash_size(@ip.exhibits(type: :fig), Origen::Specs::Exhibit).should == 4
    get_true_hash_size(@ip.exhibits(type: :table), Origen::Specs::Exhibit).should == 3
    get_true_hash_size(@ip.exhibits(id: :exhibit5), Origen::Specs::Exhibit).should == 1
    @ip.delete_all_exhibits
    @ip.exhibits(id: :exhibit4).should == nil
    @ip.exhibit(:exhibit4, :table, {}, {title: 'Exhibit 4', description: 'Exhibit 4 Description', reference: 'link4', markup: 'markup', block_id: :esdhc})
    get_true_hash_size(@ip.exhibits, Origen::Specs::Exhibit).should == 1
  end
  
  it "can see sub_block doc resource" do
    get_true_hash_size(@ip.doc_resources, Origen::Specs::Doc_Resource).should == 24
    get_true_hash_size(@ip.doc_resources(mode: :default), Origen::Specs::Doc_Resource).should == 8
    get_true_hash_size(@ip.doc_resources(mode: :low_power), Origen::Specs::Doc_Resource).should == 8
    get_true_hash_size(@ip.doc_resources(mode: :high_performance), Origen::Specs::Doc_Resource).should == 8
    get_true_hash_size(@ip.doc_resources(type: :ac), Origen::Specs::Doc_Resource).should == 12
    get_true_hash_size(@ip.doc_resources(type: :dc), Origen::Specs::Doc_Resource).should == 12
    get_true_hash_size(@ip.doc_resources(sub_type: 'input'), Origen::Specs::Doc_Resource).should == 12
    get_true_hash_size(@ip.doc_resources(sub_type: 'output'), Origen::Specs::Doc_Resource).should == 12
    get_true_hash_size(@ip.doc_resources(audience: :external), Origen::Specs::Doc_Resource).should == 12
    get_true_hash_size(@ip.doc_resources(audience: :internal), Origen::Specs::Doc_Resource).should == 12
    get_true_hash_size(@ip.doc_resources(mode: :default, type: :ac, sub_type: 'input'), Origen::Specs::Doc_Resource).should == 2
    get_true_hash_size(@ip.doc_resources(mode: :default, type: :dc, audience: :external), Origen::Specs::Doc_Resource).should == 2
    @ip.delete_all_doc_resources
    @ip.doc_resources(type: :dc).should == nil
    @ip.doc_resource({mode: :high_performance, type: :dc, sub_type: 'input', audience: :external}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    @ip.doc_resource({mode: :default, type: :dc, sub_type: 'input', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    @ip.doc_resource({mode: :low_power, type: :dc, sub_type: 'input', audience: :internal}, {title: 'Title for Table 1', note_refs: nil, exhibit_refs: nil}, {before: nil, after: nil}, {})
    get_true_hash_size(@ip.doc_resources, Origen::Specs::Doc_Resource).should == 3
  end

  it "can see sub_block power supplies" do
    get_true_hash_size(@ip.power_supplies, Origen::Specs::Power_Supply).should == 17
    get_true_hash_size(@ip.power_supplies(gen: 'GVDD'), Origen::Specs::Power_Supply).should ==  2
    get_true_hash_size(@ip.power_supplies(gen: 'DVDD'), Origen::Specs::Power_Supply).should ==  3
    get_true_hash_size(@ip.power_supplies(gen: 'XVDD'), Origen::Specs::Power_Supply).should ==  6
    get_true_hash_size(@ip.power_supplies(gen: 'SVDD'), Origen::Specs::Power_Supply).should ==  6
    get_true_hash_size(@ip.power_supplies(act: 'X4VDD'), Origen::Specs::Power_Supply).should == 1
    ps = @ip.power_supplies(act: 'X4VDD').values.first.values.first
    ps.display_name = Nokogiri::XML::DocumentFragment.parse '<ph>X4V<sub>DD</sub></ph>'
    ps.update_input
    ps.update_output
    ps.display_name.to_s.should == '<ph>X4V<sub>DD</sub></ph>'
    ps.input_display_name.to_s.should == '<ph>X4V<sub>IN</sub></ph>'
    ps.output_display_name.to_s.should == '<ph>X4V<sub>OUT</sub></ph>'
    @ip.delete_all_power_supplies    
    @ip.power_supplies(gen: 'SVDD').should == nil
    @ip.power_supply('GVDD', 'G1VDD')
    @ip.power_supply('GVDD', 'G2VDD')
    @ip.power_supply('DVDD', 'D1VDD')
    get_true_hash_size(@ip.power_supplies, Origen::Specs::Power_Supply).should == 3
  end

  it "can see sub_block overrides" do
    get_true_hash_size(@ip.overrides, Origen::Specs::Override).should == 6
    get_true_hash_size(@ip.overrides(block: :esdhc), Origen::Specs::Override).should == 3
    get_true_hash_size(@ip.overrides(block: :ddr), Origen::Specs::Override).should == 2
    get_true_hash_size(@ip.overrides(block: :i2c), Origen::Specs::Override).should == 1
    get_true_hash_size(@ip.overrides(spec_ref: :vdd), Origen::Specs::Override).should == 2
    get_true_hash_size(@ip.overrides(mode_ref: :nominal), Origen::Specs::Override).should == 3
    get_true_hash_size(@ip.overrides(mode_ref: :high_performance), Origen::Specs::Override).should == 2
    get_true_hash_size(@ip.overrides(mode_ref: :low_power), Origen::Specs::Override).should == 1
    get_true_hash_size(@ip.overrides(sub_type: 'input'), Origen::Specs::Override).should == 4
    get_true_hash_size(@ip.overrides(sub_type: 'output'), Origen::Specs::Override).should == 2
    get_true_hash_size(@ip.overrides(audience: :external), Origen::Specs::Override).should == 6
    get_true_hash_size(@ip.overrides(audience: :internal), Origen::Specs::Override).should == 0
    @ip.delete_all_overrides
    @ip.overrides(block: :esdhc).should == nil
    @ip.override({block: :esdhc, usage: true}, {spec_id: :vdd_lp, mode_ref: :low_power, sub_type: 'input', audience: :external}, {min: 0.97}, {disable: false})
    @ip.override({block: :i2c, usage: true}, {spec_id: :clk_rise, mode_ref: :high_performance, sub_type: 'input', audience: :external}, {min: 0.97}, {disable: true})
    @ip.override({block: :ddr, usage: true}, {spec_id: :vdd, mode_ref: :high_performance, sub_type: 'output', audience: :external}, {min: 0.97}, {disable: true})
    get_true_hash_size(@ip.overrides, Origen::Specs::Override).should == 3
    get_true_hash_size(@ip.overrides(block: :esdhc), Origen::Specs::Override).should == 1
    get_true_hash_size(@ip.overrides(block: :ddr), Origen::Specs::Override).should == 1
    get_true_hash_size(@ip.overrides(block: :i2c), Origen::Specs::Override).should == 1
   
  end
  
  it "can see sub_block creation info" do
    @ip.get_creation_info.author.should == 'Jim Smith'
    @ip.get_creation_info.date.should == '4 Jun 2015'
    @ip.get_creation_info.ip_block_name.should == :esdhc
    @ip.get_creation_info.revision.should =='b'
    @ip.delete_creation_info
    @ip.get_creation_info.should == nil
  end

  it "can see sub_block mode_selects" do
    get_true_hash_size(@ip.mode_selects, Origen::Specs::Mode_Select).should == 4
    get_true_hash_size(@ip.mode_selects(block: :ddr), Origen::Specs::Mode_Select).should == 2
    get_true_hash_size(@ip.mode_selects(block: :ifc1), Origen::Specs::Mode_Select).should == 1
    get_true_hash_size(@ip.mode_selects(block: :i2c1), Origen::Specs::Mode_Select).should == 1
    get_true_hash_size(@ip.mode_selects(mode: :ddr_ddr4), Origen::Specs::Mode_Select).should == 1
    @ip.delete_all_mode_selects
    @ip.mode_selects(block: :ddr).should == nil
    @ip.mode_select({name: :ddr, ds_header: 'DDR Controller', usage: true, location: 'path'}, {mode: :ddr_ddr3, supported: true}, {supply: 'G1VDD', voltage_level: '1.35V', use_diff: true})
    @ip.mode_select({name: :ifc1, ds_header: 'IFC', usage: true, location: 'path'}, {mode: :ifc1_nand, supported: true}, {supply: 'OVDD', voltage_level: '3.0V', use_diff: true})
    get_true_hash_size(@ip.mode_selects, Origen::Specs::Mode_Select).should == 2
  end
  
  it "can see sub_block documentation" do
    get_true_hash_size(@ip.documentations, Origen::Specs::Documentation).should == 10
    get_true_hash_size(@ip.documentations(section: 'Section 1'), Origen::Specs::Documentation).should == 3
    get_true_hash_size(@ip.documentations(section: 'Section 2'), Origen::Specs::Documentation).should == 4
    get_true_hash_size(@ip.documentations(section: 'Section 3'), Origen::Specs::Documentation).should == 3
    @ip.documentations(section: 'Section 4').should == nil
    get_true_hash_size(@ip.documentations(subsection: 'SubSection A'), Origen::Specs::Documentation).should == 3
    get_true_hash_size(@ip.documentations(subsection: 'SubSection B'), Origen::Specs::Documentation).should == 3
    get_true_hash_size(@ip.documentations(subsection: 'SubSection C'), Origen::Specs::Documentation).should == 2
    get_true_hash_size(@ip.documentations(subsection: 'SubSection D'), Origen::Specs::Documentation).should == 1
    @ip.documentations(subsection: 'SubSection E').should == nil
    get_true_hash_size(@ip.documentations(interface: 'SoC'), Origen::Specs::Documentation).should == 3
    get_true_hash_size(@ip.documentations(interface: 'Block A'), Origen::Specs::Documentation).should == 4
    get_true_hash_size(@ip.documentations(interface: 'Block B'), Origen::Specs::Documentation).should == 3
    @ip.documentations(interface: 'Block C').should == nil
    @ip.delete_all_documentation
    @ip.documentations.should == nil
    @ip.documentation({section: 'Section 1', subsection: 'SubSection B'}, {interface: 'SoC', type: :supply, subtype: :abs_max_ratings, mode: nil, audience: :external}, [:device1, :device2], nil)
    @ip.documentation({section: 'Section 2', subsection: 'SubSection A'}, {interface: 'Block A', type: :dc, subtype: :V3p3V, mode: nil, audience: :internal}, [:device1, :device2], nil)
    @ip.documentation({section: 'Section 2', subsection: 'SubSection B'}, {interface: 'Block A', type: :supply, subtype: nil, mode: nil, audience: :external}, [:device1, :device2], 'http://link_to_section2b.xml')
    get_true_hash_size(@ip.documentations, Origen::Specs::Documentation).should == 3
    get_true_hash_size(@ip.documentations(section: 'Section 1'), Origen::Specs::Documentation).should == 1
    get_true_hash_size(@ip.documentations(section: 'Section 2'), Origen::Specs::Documentation).should == 2
  end
  
  it 'can see sub_block version history' do
    get_true_hash_size(@ip.version_histories, Origen::Specs::Version_History).should == 4
    tmp = @ip.version_histories(label: 'label.01.02.03', debug: true)
    get_true_hash_size(tmp, Origen::Specs::Version_History).should == 1
    tmp_vh = tmp.values.first.values.first.values.first
    tmp_vh.author.should == 'Sue Bird'
    tmp_vh.date.should == 'October 1, 2016'
    tmp_vh.label.should == 'label.01.02.03'
    tmp_vh.external_changes_internal.should == false
    tmp_vh.changes.class.should == Hash
    tmp_vh.changes.should == {internal: 'Change with internal comments', external: 'For external customers'}
  end
  
  it 'can evaluate references to power domains' do
    @dut.power_domains(:vmemio).nominal_voltage.should == 1.35
    @dut.specs(:memio_voh).max.exp.should == ":vmemio * 0.8"
    @dut.specs(:memio_voh).max.value.should == 1.08
    @dut.specs(:direct_ref_spec).max.exp.should == :vmemio
    @dut.specs(:direct_ref_spec).max.value.should == 1.35
    @dut.power_domains(:voffset).nominal_voltage.should == 0.25
    @dut.specs(:memio_voh_offset).max.exp.should == ":vmemio * 0.8 - :voffset"
    @dut.specs(:memio_voh_offset).max.value.should == 0.83
  end
  
  it 'can evaluate references to clocks' do
    @dut.clocks(:core_clk).freq_target.should == 1.2.Ghz
    @dut.specs(:fmin).min.exp.should == ":core_clk * 0.9"
    @dut.specs(:fmin).min.value.should == 1.08.Ghz
  end
    
end
