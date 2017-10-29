require "spec_helper"

module ChipModeSpec

  describe "Chip Mode assignment and manipulation for top level and sub blocks" do

    class Top
      include Origen::Model

      def initialize
        add_mode :reset, brief_description: "Top Level Mode", description: "Configure the device to known state through RCW configuration and pin sampling"
        sub_block :dcfg_dcsr, base_address: 0x100000, class_name: 'DCFG_DCSR', byte_order: 'big_endian', lau: 32
        sub_block :dp_pmu1_dcsr, base_address: 0x134000, class_name: 'DP_PMU1_DCSR', byte_order: 'big_endian', lau: 32
        add_mode :native do |m|
          m.core_freq = 1.2.Ghz
          m.vdd_nom = 0.7.V
        end
      end
    end

    class DCFG_DCSR
      include Origen::Model

      def initialize
        add_mode :rcw12, description: "Configure the device with RCW 12", data_rate: 1.33e6, typ_voltage: 1.2
        reg :reg1, 0x100 do
          bits 31..0, :data
        end
        add_mode :native do |m|
          m.mem_freq = 0.8.Ghz
          m.myclk = 133.Mhz
        end
      end
    end

    class DP_PMU1_DCSR
      include Origen::Model
      attr_reader :some_attr

      def initialize(options={})
        add_mode :sub_block_mode, description: "Test out instantiating a mode in a sub_block where @owner == Origen.top_level"
        sub_block :rst_dcsr, base_address: 0x120000, class_name: 'RST_DCSR', byte_order: 'big_endian', lau: 32
      end
    end

    class RST_DCSR
      include Origen::Model

      def initialize
        add_mode :nested_sub_block_mode, brief_description: "Sub Block Mode", description: "Test out instantiating a mode in a nested sub_block", data_rate: '1200', data_rate_unit: 'Mhz'
        reg :reg1, 0x100, path: "reg1_reg" do
          bits 11..10, :d7
          bits 9..8,   :d6, abs_path: "blah.d6_reg"
          bits 7..6,   :d5, path: "d5_reg"
          bits 5..4,   :d4, path: ".d4_reg"
          bit  3,      :d3
          bit  2,      :d2, abs_path: "blah.d2_reg"
          bit  1,      :d1, path: "d1_reg"
          bit  0,      :d0, path: ".d0"
        end
      end
    end

    it "can manipulate the top level modes" do
      t = Top.new
      t.respond_to?(:dcfg_dcsr).should == true
      t.modes.should == [:reset, :native]
      t.mode = :reset
      t.mode.brief_description.should == "Top Level Mode"
      t.mode.description.should == "Configure the device to known state through RCW configuration and pin sampling"
      t.add_mode :new_mode, description: "Top mode I just added"
      t.has_mode?(:new_mode).should == true
      t.modes(:new_mode).description.should == "Top mode I just added"
      t.mode = :native
      t.mode.core_freq.should == 1200000000.0
      t.mode.vdd_nom.should == 0.7
    end

    it "can manipulate the sub_block modes" do
      t = Top.new
      t.dcfg_dcsr.modes.count.should == 2
      t.dcfg_dcsr.mode = :rcw12
      t.dcfg_dcsr.mode.name.should == :rcw12
      t.dcfg_dcsr.mode.typ_voltage == 1.2
      t.dcfg_dcsr.mode.description.should == "Configure the device with RCW 12"
      t.dp_pmu1_dcsr.rst_dcsr.modes.should == [:nested_sub_block_mode]
      t.dp_pmu1_dcsr.rst_dcsr.mode = :nested_sub_block_mode
      t.dp_pmu1_dcsr.rst_dcsr.mode.brief_description.should == "Sub Block Mode"
      t.dp_pmu1_dcsr.rst_dcsr.mode.description.should == "Test out instantiating a mode in a nested sub_block"
      t.dp_pmu1_dcsr.rst_dcsr.delete_all_modes # Should only delete the modes in this sub_block
      t.dp_pmu1_dcsr.rst_dcsr.modes.should == []
      t.dp_pmu1_dcsr.modes.first.should == :sub_block_mode
    end

    it 'can handle data rates and data rate unit conversion' do
      t = Top.new
      t.dp_pmu1_dcsr.rst_dcsr.mode = :nested_sub_block_mode
      t.dp_pmu1_dcsr.rst_dcsr.mode.data_rate.should == 1200000000
      t.dp_pmu1_dcsr.rst_dcsr.mode.data_rate(absolute_number: false).should == 1200
      t.dcfg_dcsr.mode = :rcw12
      t.dcfg_dcsr.mode.data_rate.should == 1.33e6
    end
    
    it 'can pass the DUT mode to child IP by default (if defined)' do
      t = Top.new
      t.mode = :native
      t.dcfg_dcsr.mode.id.should == :native
      t.dcfg_dcsr.mode.mem_freq.should == 0.8.Ghz
      t.dcfg_dcsr.mode.myclk.should == 133.Mhz
      t.dcfg_dcsr.mode = :rcw12
      t.mode.id.should == :native
      t.dcfg_dcsr.mode.id.should == :rcw12
      t.dcfg_dcsr.mode.typ_voltage == 1.2
    end
  end
end
