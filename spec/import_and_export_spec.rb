require "spec_helper"

describe "Model import and export" do

  before :each do
    Origen.app.unload_target!
  end

  after :all do
    Origen.app.unload_target!
  end

  def load_import_model(options = {})
    Origen.target.temporary = -> { ImportModel.new(options) }
    Origen.target.load!
  end

  def load_export_model(options = {})
    Origen.target.temporary = -> { ExportModel.new(options) }
    Origen.target.load!
  end

  class ExportModel
    include Origen::TopLevel

    def initialize(options = {})
      add_package :bga
      add_package :pcs do |package|
        package.insertion_type = :wafer_sort
      end
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
      add_virtual_pin :relay1
      add_virtual_pin :relay2, packages: [:bga]

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
      reg :ctrl, 0x0024, size: 16, str_meta: "a's", str_meta2: '"works?"'  do |reg|
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

      # ** A MSB0 Test Case **
      # Blah-ba-bi-blah
      # just following the comment pattern above
      reg :msb0_test, 0x0028, size: 16, bit_order: :msb0, some_attr: true, another_attr: :testing, third_attr: nil, fourth_attr: 'string_attr' do |reg|
        reg.bit 8,  :ale
        reg.bit 9,  :xsfg
        reg.bit 10, :yml
        reg.bit 11..15, :field, reset: 0x1f
      end
    end
  end

  class ImportModel
    include Origen::TopLevel

    def initialize(options = {})
      sub_block :block1, lazy: true

      import 'export1', options
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

  it "export optionally only clobbers rb files" do
    FileUtils.rm_rf(File.join(Origen.root, 'vendor', 'lib'))
    load_export_model
    File.exist?("#{Origen.root}/vendor/lib/models/origen/export1.rb").should == false
    dut.export 'export1', include_timestamp: false
    File.exist?("#{Origen.root}/vendor/lib/models/origen/non_origen_meta_data.md").should == false
    File.open("#{Origen.root}/vendor/lib/models/origen/non_origen_meta_data.md", "w") { |f| f.puts 'pretend metadata file' }
    dut.export 'export1', include_timestamp: false, rm_rb_only: true
    File.exist?("#{Origen.root}/vendor/lib/models/origen/non_origen_meta_data.md").should == true    
  end

  it "import is alive" do
    load_import_model
    dut.is_a?(ImportModel).should == true
  end

  it "export and import from a custom dir and namespace works" do
    dir = "#{Origen.root}/tmp/my_exports"
    FileUtils.rm_rf(dir)
    load_export_model(dir: dir, namespace: :blah)
    File.exist?("#{dir}/blah/export1.rb").should == false
    dut.export 'export1', dir: dir, namespace: :blah
    File.exist?("#{dir}/blah/export1.rb").should == true
    load_import_model(dir: dir, namespace: :blah)
    dut.is_a?(ImportModel).should == true
    dut.has_pin?(:pinx).should == true
    dut.block1.x.base_address.should == 0x4000_0000
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
    dut.virtual_pins.size.should == 2
    dut.virtual_pins.include?(:relay1).should == true
    dut.virtual_pins.include?(:relay2).should == true
  end
  
  it 'handles pins package metadata' do
    load_import_model
    dut.has_pin?(:tdo).should == true
    dut.pin(:tdo).packages.keys.should == [:bga, :pcs]
    dut.packages.should == [:bga, :pcs]
    dut.virtual_pins.size.should == 2
    dut.virtual_pins.include?(:relay1).should == true
    dut.virtual_pins.include?(:relay2).should == true
    dut.package = :bga
    dut.pin(:tdo).location.should == 'BF32'
    dut.pin(:tdo).dib_assignment.should == [10104]
    dut.virtual_pins.size.should == 1
    dut.virtual_pins.include?(:relay1).should == false
    dut.virtual_pins.include?(:relay2).should == true
    dut.package = :pcs
    dut.pin(:tdo).location.should == 'BF30'
    dut.pin(:tdo).dib_assignment.should == [31808]
  end

  it "handles package customization" do
    load_export_model
    dut.package = :bga
    dut.package.insertion_type.should == nil
    dut.package = :pcs
    dut.package.insertion_type.should == :wafer_sort
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

  it "handles msb0 registers" do
    load_import_model
    reg = dut.block1.x.msb0_test
    reg.bit_order.should == :msb0
    reg.bit(:ale).position.should == 7
    reg.bit(:field).position.should == 0
    reg.bit(:field).size.should == 5
  end

  it "handles register metadata" do
    load_import_model
    reg = dut.block1.x.msb0_test
    reg.meta[:some_attr].should == true
    reg.meta[:another_attr].should == :testing
    reg.meta[:third_attr].should == nil
    reg.meta[:fourth_attr].should == 'string_attr'

    reg = dut.block1.x.ctrl
    reg.meta[:str_meta].should == "a's"
    reg.meta[:str_meta2].should == '"works?"'
  end

  it "gracefully adds to existing sub-blocks without instantiating them" do
    load_import_model
    dut.block1.is_a?(Origen::SubBlocks::Placeholder).should == true
    dut.block1.x.ctrl.should be
    dut.block1.is_a?(Origen::SubBlocks::Placeholder).should == false
  end
end
