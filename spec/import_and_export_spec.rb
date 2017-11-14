require "spec_helper"

describe "Model import and export" do

  before :each do
    Origen.app.unload_target!
  end

  after :all do
    Origen.app.unload_target!
  end

  def load_import_model
    Origen.target.temporary = -> { ImportModel.new }
    Origen.target.load!
  end

  def load_export_model
    Origen.target.temporary = -> { ExportModel.new }
    Origen.target.load!
  end

  class ExportModel
    include Origen::TopLevel

    def initialize(options = {})
      add_package :bga
      add_package :pcs
      add_pin :pinx
      add_pin :piny, reset: :drive_hi, direction: :output, meta: { a: "1", b: 2 }
      add_pin :tdo, packages: { bga: { location: 'BF32', dib_assignment: [10104] }, pcs: { location: 'BF30', dib_assignment: [31808] } }
      add_pins :porta, size: 32
      add_pins :portb, size: 16, endian: :little

      add_power_pin :vdd1, voltage: 3, current_limit: 50.mA, meta: { min_voltage: 1.5 }
      add_power_pin :vdd2
      add_ground_pin :gnd1
      add_ground_pin :gnd2
      add_ground_pin :gnd3
      add_power_pin_group :vdd, :vdd1, :vdd2
      add_ground_pin_group :gnd, :gnd1, :gnd2, :gnd3

      sub_block :block1, class_name: 'Sub1'
    end
  end

  class Sub1
    include Origen::Model

    def initialize
      sub_block :x, class_name: 'Sub2', base_address: 0x4000_0000
    end
  end

  class Sub2
    include Origen::Model

    def initialize
      # ** Some Control Register **
      # Blah, blah,
      # and some more blah
      reg :ctrl, 0x0024, size: 16 do |reg|
        reg.bit 7, :coco, access: :ro
        reg.bit 6, :aien
        # **Some Diff Bit** - This is a...
        # blah, blah
        #
        # 0 | It's off
        # 1 | It's on
        reg.bit 5, :diff
        reg.bit 4..0, :adch, reset: 0x1F
      end
    end
  end

  class ImportModel
    include Origen::TopLevel

    def initialize(options = {})
      sub_block :block1

      import 'export1'
    end
  end

  it "export is alive" do
    FileUtils.rm_rf(File.join(Origen.root, 'vendor', 'lib'))
    load_export_model
    dut.is_a?(ExportModel).should == true
    File.exist?("#{Origen.root}/vendor/lib/models/origen/export1.rb").should == false
    dut.export 'export1', include_timestamp: false
    File.exist?("#{Origen.root}/vendor/lib/models/origen/export1.rb").should == true
  end

  it "import is alive" do
    load_import_model
    dut.is_a?(ImportModel).should == true
  end

  it "handles pins" do
    load_import_model
    dut.has_pin?(:pinx).should == true
    dut.pin(:pinx).instance_variable_get("@reset").should == :dont_care
    dut.pin(:pinx).direction.should == :io
    dut.has_pin?(:piny).should == true
    dut.pin(:piny).instance_variable_get("@reset").should == :drive_hi
    dut.pin(:piny).direction.should == :output
    dut.pin(:piny).meta[:a].should == "1"
    dut.pin(:piny).meta[:b].should == 2
    dut.pins(:porta).size.should == 32
    dut.pins(:porta)[0].id.should == :porta0
    dut.pins(:porta).endian.should == :big
    dut.pins(:portb).size.should == 16
    dut.pins(:portb)[0].id.should == :portb0
    dut.pins(:portb).endian.should == :little
    dut.power_pins.size.should == 2
    dut.power_pins(:vdd).size.should == 2
    dut.ground_pins.size.should == 3
    dut.ground_pins(:gnd).size.should == 3
    dut.power_pin(:vdd1).voltage.should == 3
    dut.power_pin(:vdd1).current_limit.should == 50.mA
    dut.power_pin(:vdd1).meta[:min_voltage].should == 1.5
  end
  
  it 'handles pins package metadata' do
    load_import_model
    dut.has_pin?(:tdo).should == true
    dut.pin(:tdo).packages.keys.should == [:bga, :pcs]
    dut.packages.should == [:bga, :pcs]
    dut.package = :bga
    dut.pin(:tdo).location.should == 'BF32'
    dut.pin(:tdo).dib_assignment.should == [10104]
    dut.package = :pcs
    dut.pin(:tdo).location.should == 'BF30'
    dut.pin(:tdo).dib_assignment.should == [31808]
  end

  it "handles sub-blocks" do
    load_import_model
    dut.block1.x.should be
    dut.block1.x.base_address.should == 0x4000_0000
  end

  it "handles registers" do
    load_import_model
    reg = dut.block1.x.ctrl
    reg.description[1].should == 'Blah, blah,'
    reg.size.should == 16
    reg.coco.access.should == :ro
    reg.adch.size.should == 5
    reg.adch.reset_val.should == 0x1F
    reg.diff.bit_value_descriptions[0].should == "It's off"
    reg.diff.bit_value_descriptions[1].should == "It's on"
  end

  it "gracefully adds to existing sub-blocks without instantiating them" do
    load_import_model
    dut.block1.is_a?(Origen::SubBlocks::Placeholder).should == true
    dut.block1.x.ctrl.should be
    dut.block1.is_a?(Origen::SubBlocks::Placeholder).should == false
  end
end
