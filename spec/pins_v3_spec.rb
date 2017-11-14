require "spec_helper"

# Some dummy classes to test out the pins module
class PinsV3Dut

  include Origen::TopLevel

  attr_reader :sub1
  attr_accessor :configuration

  def initialize
    add_package :p1
    add_package :p2
    add_mode :m1
    add_mode :m2
    add_mode :user
    add_mode :nvmbist
    @sub1 = PinsV3Sub.new
  end

end

class PinsV3Sub

  include Origen::Pins

end

class IncorrectPackageDut
  include Origen::TopLevel
  
  def initialize
    add_pin :pinx
  end
  
  def add_packages
    add_package :pcs
  end
  
end

describe "Origen Pin API v3" do

  before :each do
    Origen.app.unload_target!
    Origen.load_target("configurable", dut: PinsV3Dut)
  end

  describe "Adding and scoping pins" do
    
    it "pins can be added" do
      $dut.add_pin :pinx
      $dut.add_pin :piny do |pin|
        pin.direction = :input
        pin.rtl_name = "piny[0]"
      end
      $dut.add_pin do |pin|
        pin.id = :pinz
      end
      $dut.has_pin?(:pinw).should == false
      $dut.has_pin?(:pinx).should == true
      $dut.has_pin?(:piny).should == true
      $dut.has_pin?(:pinz).should == true
      $dut.pin(:pinx).direction.should == :io
      $dut.pin(:piny).direction.should == :input
      $dut.pin(:pinz).direction.should == :io
      # Verify [] notation works
      $dut.pin[:pinx].direction.should == :io
      $dut.pin[:piny].direction.should == :input
      $dut.pin[:pinz].direction.should == :io
      $dut.pin[:pinz].rtl_name.should == nil
      $dut.pin[:piny].rtl_name.should == "piny[0]"
    end

    it "pins know what packages they are in" do
      $dut.add_pin :pin1, packages: [:p1, :p2]
      $dut.add_pin :pin2, package: :p1
      $dut.add_pin :pin3, packages: [:p1, :p2]
      $dut.add_pin :pin4
      $dut.pins.size.should == 4
      $dut.with_package :p1 do
        $dut.pins.size.should == 3
        $dut.has_pin?(:pin2).should == true
        lambda do
          $dut.pin(:pin2)
        end.should_not raise_error
      end
      $dut.with_package :p2 do
        $dut.pins.size.should == 2
        $dut.has_pin?(:pin2).should == false
        #lambda do
        #  $dut.pin(:pin2)
        #end.should raise_error
      end
    end

    it "pin locations can be set by package" do
      $dut.add_pin :pin1, packages: [:p1, :p2]
      $dut.add_pin :pin2, package: {p1: {location: "B2"}}
      $dut.add_pin :pin3, packages: [:p1, :p2]
      $dut.add_pin :pin4
      # With no package set, all pins are available, however package
      # aliases should only work when enabled by the current scope
      $dut.pin(:pin1).add_location "A5"
      $dut.has_pin?(:a5).should == true # Because the location is not scoped
      $dut.pin(:a5).should == $dut.pin(:pin1)
      $dut.pin(:pin3).add_location "B3", package: :p1
      $dut.has_pin?(:b3).should == false
      $dut.pin(:pin3).add_location "B2", package: :p2
      $dut.has_pin?(:b2).should == false

      $dut.with_package :p1 do
        $dut.pin(:pin1).location.should == "A5"
        $dut.pin(:pin2).location.should == "B2"
        $dut.pin(:pin3).location.should == "B3"
        $dut.has_pin?(:a5).should == true
        $dut.pin(:a5).should == $dut.pin(:pin1)
        $dut.has_pin?(:b2).should == true
        $dut.pin(:b2).should == $dut.pin(:pin2)
        $dut.has_pin?(:b3).should == true
        $dut.pin(:b3).should == $dut.pin(:pin3)
      end

      $dut.with_package :p2 do
        $dut.pin(:pin1).location.should == "A5"
        $dut.pin(:pin3).location.should == "B2"
        $dut.has_pin?(:a5).should == true
        $dut.pin(:a5).should == $dut.pin(:pin1)
        $dut.has_pin?(:b2).should == true
        $dut.pin(:b2).should == $dut.pin(:pin3)
        $dut.has_pin?(:b3).should == false
      end
    end

    it "multiple package locations and dib_assignments can be set" do
      pin = $dut.add_pin(:pin1)
      pin2 = $dut.add_pin(:pin2)
      pin.add_location "B2", package: :p1
      pin.add_location "B3", package: :p2
      pin2.add_location "B1", package: :p1
      pin2.add_location "B1", package: :p2
      $dut.has_pin?(:b1).should == false
      $dut.has_pin?(:b2).should == false
      $dut.has_pin?(:b3).should == false
      $dut.package = :p1
      $dut.has_pin?(:b1).should == true
      $dut.has_pin?(:b2).should == true
      $dut.pin(:b2).should == pin
      $dut.has_pin?(:b3).should == false
      $dut.package = :p2
      $dut.has_pin?(:b1).should == true
      $dut.has_pin?(:b2).should == false
      $dut.has_pin?(:b3).should == true
      $dut.pin(:b3).should == pin
    end

    it "pins are scoped by package" do
      $dut.package.should == nil
      $dut.add_pin :pinx
      # Pins specified without a package are added to
      # the current package
      $dut.with_package :p1 do
        $dut.add_pin :p1_pinx
        $dut.add_pin :p1_piny do |pin|
          pin.direction = :input
        end
      end
      $dut.with_package :p2 do
        $dut.add_pin :p2_pinx
        $dut.add_pin :p2_piny do |pin|
          pin.direction = :input
          pin.dib_assignment[0] = '23.sense16'
          pin.dib_assignment[1] = '23.sense10'
        end
        $dut.pins(:p2_pinx).dib_assignment.should == []
        $dut.pins(:p2_piny).dib_assignment.size.should == 2
        $dut.pins(:p2_piny).dib_assignment[0].should == '23.sense16'
        $dut.pins(:p2_piny).dib_assignment[1].should == '23.sense10'
        $dut.pins(:p2_piny).sites.should == 2
      end
      $dut.package = nil
      # Pins can be added to multiple packages with an explicit declaration
      $dut.add_pin :p1p2_pinx, packages: [:p1, :p2]
      $dut.package.should == nil

      # All pins available if no package filter set
      $dut.has_pin?(:pinx).should == true
      $dut.has_pin?(:p1_pinx).should == true
      $dut.has_pin?(:p1_piny).should == true
      $dut.has_pin?(:p2_pinx).should == true
      $dut.has_pin?(:p2_piny).should == true
      $dut.has_pin?(:p1p2_pinx).should == true
      $dut.pins.size.should == 6

      $dut.package = :p1
      $dut.has_pin?(:pinx).should == false
      $dut.has_pin?(:p1_pinx).should == true
      $dut.has_pin?(:p1_piny).should == true
      $dut.has_pin?(:p2_pinx).should == false
      $dut.has_pin?(:p2_piny).should == false
      $dut.has_pin?(:p1p2_pinx).should == true
      $dut.pins.size.should == 3

      $dut.package = :p2
      $dut.has_pin?(:pinx).should == false
      $dut.has_pin?(:p1_pinx).should == false
      $dut.has_pin?(:p1_piny).should == false
      $dut.has_pin?(:p2_pinx).should == true
      $dut.has_pin?(:p2_piny).should == true
      $dut.has_pin?(:p1p2_pinx).should == true
      $dut.pins.size.should == 3
    end

    # SMcG - Pin availability is now only scoped by package
    #it "pins are scoped by mode" do
    #  $dut.add_pin :pin1, modes: [:user, :nvmbist]
    #  $dut.add_pin :pin2, modes: [:user, :nvmbist]
    #  $dut.add_pin :pin3, mode: :user
    #  $dut.add_pin :pin4, modes: :all
    #  $dut.pins.size.should == 1
    #  $dut.with_mode :user do
    #    $dut.pins.size.should == 4
    #    $dut.has_pin?(:pin3).should == true
    #    lambda do
    #      $dut.pin(:pin3)
    #    end.should_not raise_error
    #  end
    #  $dut.with_mode :nvmbist do
    #    $dut.pins.size.should == 3
    #    $dut.has_pin?(:pin3).should == false
    #    #lambda do
    #    #  $dut.pin(:pin3)
    #    #end.should raise_error
    #  end
    #end

    # SMcG - Pin availability is now only scoped by package
    #it "pins are scoped by configuration" do
    #  $dut.add_pin :pin1, configurations: [:default, :alt0]
    #  $dut.add_pin :pin2, configurations: [:default, :alt1]
    #  $dut.add_pin :pin3, configurations: [:default, :alt0, :alt1]
    #  $dut.add_pin :pin4, configurations: :all
    #  $dut.pins.size.should == 1

    #  $dut.configuration = :default
    #  $dut.pins.size.should == 4
    #  $dut.has_pin?(:pin2).should == true
    #  lambda do
    #    $dut.pin(:pin2)
    #  end.should_not raise_error

    #  $dut.configuration = :alt0
    #  $dut.pins.size.should == 3
    #  $dut.has_pin?(:pin2).should == false
    #  #lambda do
    #  #  $dut.pin(:pin2)
    #  #end.should raise_error

    #  # Test pin-level configuration override
    #  $dut.all_pins(:pin2).configuration = :alt1
    #  $dut.has_pin?(:pin2).should == true
    #  $dut.pins.size.should == 4
    #end

  end

  describe "Adding and scoping pin aliases" do

    it "aliases are scoped by package" do
      $dut.package.should == nil
      $dut.add_pin :pinx
      $dut.add_pin_alias :pinx_, :pinx
      $dut.with_package :p1 do
        $dut.add_pin :piny
        $dut.add_pin_alias :piny_, :piny
      end
      $dut.has_pin?(:pinx).should == true
      $dut.has_pin?(:pinx_).should == true
      $dut.has_pin?(:piny).should == true # Package filtering only applied when a package is set
      $dut.has_pin?(:piny_).should == false
      $dut.with_package :p1 do
        $dut.has_pin?(:pinx).should == false
        $dut.has_pin?(:pinx_).should == false
        $dut.has_pin?(:piny).should == true
        $dut.has_pin?(:piny_).should == true
      end
    end

    it "aliases are scoped by mode" do
      $dut.add_pin :pinx
      $dut.pin_alias :aliasx, :pinx
      $dut.pin(:aliasx).should == $dut.pin(:pinx)
      $dut.has_pin?(:aliasx).should == true
      $dut.pin_alias :aliasm1, :pinx, mode: :m1
      $dut.pin_alias :aliasm2, :pinx, mode: :m2
      $dut.pin_alias :aliasa1, :pinx, mode: :all
      $dut.has_pin?(:aliasm1).should == false
      $dut.has_pin?(:aliasm2).should == false
      $dut.has_pin?(:aliasa1).should == true
      $dut.mode = :m1
      $dut.has_pin?(:pinx).should == true
      $dut.has_pin?(:aliasx).should == true # An alias with no mode specified is treated like mode: :all
      $dut.has_pin?(:aliasm1).should == true
      $dut.has_pin?(:aliasm2).should == false
      $dut.has_pin?(:aliasa1).should == true
      $dut.mode = :m2
      $dut.has_pin?(:pinx).should == true
      $dut.has_pin?(:aliasx).should == true
      $dut.has_pin?(:aliasm1).should == false
      $dut.has_pin?(:aliasm2).should == true
      $dut.has_pin?(:aliasa1).should == true
    end

    it "aliases will be applied to the current mode if one has been defined" do
      $dut.add_pin :pinx
      $dut.with_mode :m1 do
        $dut.pin_alias :aliasm1, :pinx
      end
      $dut.has_pin?(:pinx).should == true
      $dut.has_pin?(:aliasm1).should == false
      $dut.mode = :m1
      $dut.has_pin?(:pinx).should == true
      $dut.has_pin?(:aliasm1).should == true
    end

  end

  describe "Adding and scoping pin groups" do

    # Removed this feature for now, in reality the group called pta could be comprised
    # of a non-linear collection of pta pins.
    #it "pin collections are automatically generated for pins that end in a number" do
    #  $dut.add_pin(:pa0)
    #  $dut.add_pin(:pa1)
    #  $dut.add_pin(:pa2)
    #  $dut.add_pin(:pa3)
    #  $dut.pins(:pa).size.should == 4
    #end

    it "add_pin_group returns the group" do
      p = $dut.add_pin :pinx
      g = $dut.add_pin_group :g1, :pinx
      p.should == $dut.pins(:pinx)
      g.should == $dut.pins(:g1)
    end

    it "pin groups can be declared directly at pin definition time" do
      $dut.add_pins :pb, size: 8 do |group|
        group.direction = :input
      end
      $dut.pins(:pb).size.should == 8
      $dut.pins(:pb).direction.should == :input
      # Indexed pin names are synthesized
      $dut.pin(:pb0).direction.should == :input
      $dut.pin(:pb7).direction.should == :input
      # Or accessible via a regular index
      $dut.pin(:pb)[0].direction.should == :input
      $dut.pin(:pb)[7].direction.should == :input
      # Works with a late-defined ID
      $dut.add_pins size: 8 do |group|
        group.id = :pc
        group.direction = :input
      end
      $dut.pins(:pc).size.should == 8
      $dut.pins(:pc).direction.should == :input
      # Indexed pin names are synthesized
      $dut.pin(:pc0).direction.should == :input
      $dut.pin(:pc7).direction.should == :input
      # Or accessible via a regular index
      $dut.pin(:pc)[0].direction.should == :input
      $dut.pin(:pc)[7].direction.should == :input
      # Verify we are talking about the same pin!
      $dut.pin(:pc0).should == $dut.pin(:pc)[0]
      $dut.pin(:pc7).should == $dut.pin(:pc)[7]
      # Works with a simple inline definition
      $dut.add_pins :pd, size: 16
      $dut.pins(:pd).size.should == 16
    end

    it "endianness of pin group tests" do
      $dut.add_pins :pb, size: 4
      $dut.add_pins :pc, size: 4, endian: :little
      $dut.pins(:pb).endian.should == :big
      $dut.pins(:pc).endian.should == :little
      # Big endian should yield the most significant pin first
      first = nil
      $dut.pins(:pb).each { |pin| first ||= pin }
      first.should == $dut.pins(:pb3)
      # Little endian should yield the least significant pin first
      first = nil
      $dut.pins(:pc).each { |pin| first ||= pin }
      first.should == $dut.pins(:pc0)
      # The data always reads back as written
      $dut.pins(:pb).drive(0b1100)
      $dut.pins(:pc).drive(0b1100)
      $dut.pins(:pb).data.should == 0b1100
      $dut.pins(:pc).data.should == 0b1100
      # But internally the data is stored according to the endianness
      $dut.pins(:pb0).data.should == 0
      $dut.pins(:pb1).data.should == 0
      $dut.pins(:pb2).data.should == 1
      $dut.pins(:pb3).data.should == 1
      $dut.pins(:pc0).data.should == 1
      $dut.pins(:pc1).data.should == 1
      $dut.pins(:pc2).data.should == 0
      $dut.pins(:pc3).data.should == 0
      $dut.pins(:pb)[0].data.should == 0
      $dut.pins(:pb)[1].data.should == 0
      $dut.pins(:pb)[2].data.should == 1
      $dut.pins(:pb)[3].data.should == 1
      $dut.pins(:pc)[0].data.should == 1
      $dut.pins(:pc)[1].data.should == 1
      $dut.pins(:pc)[2].data.should == 0
      $dut.pins(:pc)[3].data.should == 0
      # Sub collections pick up the parent's endianness
      sub = $dut.pins(:pb)[1,2]
      sub.endian.should == :big
      sub.data.should == 0b10
      sub[0].data.should == 0
      sub[1].data.should == 1
      sub = $dut.pins(:pc)[1,2]
      sub.endian.should == :little
      sub.data.should == 0b10
      sub[0].data.should == 1
      sub[1].data.should == 0
    end

    it "anonymous pin groups can be created at runtime" do
      $dut.add_pins :pb, size: 8
      $dut.pins(:pb).data.should == 0x00
      $dut.pins(:pb)[0,1,2,3].drive(0x5)
      $dut.pins(:pb).data.should == 0x05
      $dut.pins(:pb)[4..7].drive(0xA)
      $dut.pins(:pb).data.should == 0xA5
      $dut.pins(:pb)[7..4].drive(0x5)
      $dut.pins(:pb).data.should == 0x55
    end

    it "pin groups can be composed from non-linear collections of pins" do
      [:pta19, :pta18, :pta12, :pta11, :pta3, :pta2, :pta1, :pta0].each do |id|
        $dut.add_pin id
      end
      $dut.add_pin_group :pta, :pta19, :pta18, :pta12, :pta11, :pta3, :pta2, :pta1, :pta0
      $dut.pins(:pta).size.should == 8
      $dut.pins(:pta)[7].should == $dut.pins(:pta19)
    end

    it "or named groups can be composed from existing pins" do
      $dut.add_pin(:tdi)
      $dut.add_pin(:tdo)
      $dut.add_pin(:tclk)
      $dut.add_pin(:tms)
      # Various ways of declaring a pin group...
      $dut.add_pin_group :jtag do |group|
        group << :tdi
        group.add_pin :tdo
        group << :tclk
        group << :tms
      end
      $dut.pins(:jtag).size.should == 4
      $dut.add_pin_group :jtag2, :tdi, :tdo, :tclk, :tms
      $dut.pins(:jtag2).size.should == 4
      $dut.pins(:jtag).drive(0xB)
      $dut.pins(:jtag).data.should == (0xB)
      $dut.pins(:jtag2).drive(0xB)
      $dut.pins(:jtag2).data.should == (0xB)
      $dut.add_pins :pb, size: 8
      $dut.add_pin_group :pb_lower, $dut.pins(:pb)[3..0]
      $dut.add_pin_group :pb_upper do |group|
        group << $dut.pins(:pb)[7..4]
      end
      $dut.pins(:pb).data.should == 0x00
      $dut.pins(:pb_lower).drive(0x3)
      $dut.pins(:pb_upper).drive(0xE)
      $dut.pins(:pb).data.should == 0xE3
    end

    # SMcG - Pin availability is now only scoped by package
    #it "pin groups are scoped by mode" do
    #  $dut.add_pin(:pin1)
    #  $dut.add_pin(:pin2)
    #  $dut.add_pin_group :g1, :pin1, :pin2
    #  $dut.add_pin_group :g2, :pin1, :pin2, mode: :m1
    #  $dut.add_pin_group :g3, :pin1, :pin2, modes: [:m1, :m2]
    #  $dut.add_pin_group :g4, mode: :m2 do |group|
    #    group << :pin1
    #    group << :pin2
    #  end
    #  $dut.mode = :m2
    #  $dut.add_pin_group :g5, :pin1, :pin2
    #  $dut.mode = nil
    #  $dut.has_pins?(:g1).should == true
    #  $dut.has_pins?(:g2).should == false
    #  $dut.has_pins?(:g3).should == false
    #  $dut.has_pins?(:g4).should == false
    #  $dut.has_pins?(:g5).should == false
    #  $dut.mode = :m1
    #  $dut.has_pins?(:g1).should == true  # No mode specified is treated like :all
    #  $dut.has_pins?(:g2).should == true
    #  $dut.has_pins?(:g3).should == true
    #  $dut.has_pins?(:g4).should == false
    #  $dut.has_pins?(:g5).should == false
    #  $dut.mode = :m2
    #  $dut.has_pins?(:g1).should == true
    #  $dut.has_pins?(:g2).should == false
    #  $dut.has_pins?(:g3).should == true
    #  $dut.has_pins?(:g4).should == true
    #  $dut.has_pins?(:g5).should == true
    #end

    it "pin groups are scoped by package" do
      $dut.add_pin(:pin1)
      $dut.add_pin(:pin2)
      $dut.add_pin(:pin3)
      $dut.add_pin_group :g1, :pin1, :pin2, package: :p1
      $dut.add_pin_group :g1, :pin1, :pin2, :pin3, package: :p2
      $dut.has_pins?(:g1).should == false
      $dut.pin_groups.size.should == 0
      $dut.package = :p1
      $dut.has_pins?(:g1).should == true
      $dut.pins(:g1).size.should == 2
      $dut.pin_groups.size.should == 1
      $dut.package = :p2
      $dut.has_pins?(:g1).should == true
      $dut.pins(:g1).size.should == 3
      $dut.pin_groups.size.should == 1
    end

  end

  describe "Working with pins from sub-modules" do

    it "pins can be added from sub modules" do
      $dut.sub1.add_pin :subpin1
      $dut.sub1.has_pin?(:subpin1).should == true
      $dut.has_pin?(:subpin1).should == true
    end

    it "aliases and groups can be added from sub modules" do
      $dut.add_pin :pinx
      $dut.sub1.add_pin_alias :subpin1, :pinx
      $dut.pin(:pinx).should == $dut.sub1.pin(:subpin1)
      $dut.sub1.pin(:pinx).should == $dut.sub1.pin(:subpin1)
      $dut.pin(:subpin1).should == $dut.pin(:subpin1)
    end

    it "pins for the current package can be accessed from sub modules" do
      $dut.add_pin :pinx
      $dut.pin(:pinx).should be
      $dut.pin(:pinx).should == $dut.sub1.pin(:pinx)
    end

    it "aliases for the current mode can be accessed from sub modules" do
      $dut.add_pin :pinx
      $dut.pin_alias :aliasx, :pinx
      $dut.pin(:pinx).should == $dut.sub1.pin(:aliasx)
    end

  end

  describe "Adding and scoping pin functions" do

    it "pin functions can be added" do
      $dut.add_pin :pinx
      $dut.pin(:pinx).name.should == :pinx
      $dut.pin(:pinx).add_function :nvm_fail
      # Without a scope a function will apply to all modes/configurations
      $dut.pin(:pinx).name.should == :nvm_fail
    end

    it "pin functions can be scoped by mode" do
      $dut.add_pin :pinx
      $dut.add_pin :piny
      $dut.pin(:pinx).add_function :nvm_fail, direction: :output, mode: :nvmbist
      $dut.pin(:pinx).add_function :tdi, direction: :input, mode: :user
      $dut.pin(:piny).add_function :tdo, direction: :output, modes: :all

      $dut.pin(:pinx).name.should == :pinx
      $dut.pin(:pinx).direction.should == :io
      $dut.pin(:piny).name.should == :tdo
      $dut.pin(:piny).direction.should == :output

      $dut.mode = :user
      $dut.pin(:pinx).name.should == :tdi
      $dut.pin(:pinx).direction.should == :input
      $dut.pin(:piny).name.should == :tdo
      $dut.pin(:piny).direction.should == :output

      $dut.mode = :nvmbist
      $dut.pin(:pinx).name.should == :nvm_fail
      $dut.pin(:pinx).direction.should == :output
      $dut.pin(:piny).name.should == :tdo
      $dut.pin(:piny).direction.should == :output
    end

    it "pin meta data can be added and also scoped by mode" do
      $dut.add_pin :pinx, meta: { a: 2, c: 1 }
      $dut.add_pin :piny
      $dut.pin(:pinx).add_function :nvm_fail, meta: { a: 1 }, mode: :nvmbist
      $dut.pin(:pinx).add_function :tdi,  meta: { b: 1 }, mode: :user
      $dut.mode = :nvmbist
      $dut.pin(:pinx).meta[:a].should == 1  # Function specific overrides the default
      $dut.pin(:pinx).meta[:b].should == nil
      $dut.pin(:pinx).meta[:c].should == 1
      $dut.mode = :user
      $dut.pin(:pinx).meta[:a].should == 2
      $dut.pin(:pinx).meta[:b].should == 1
      $dut.pin(:pinx).meta[:c].should == 1
      # Test for default meta data hash
      $dut.pin(:piny).meta.should == {}
      # Make sure we don't break legacy apps where the function-specific meta data might not be a hash
      $dut.pin(:pinx).add_function :m1,  meta: "Some string data", mode: :m1
      $dut.mode = :m1
      $dut.pin(:pinx).meta.should == "Some string data"
    end

    it "pin functions can be scoped by configuration" do
      $dut.add_pin :pinx
      $dut.add_pin :piny
      $dut.pin(:pinx).add_function :nvm_fail, direction: :output, configuration: :nvmbist
      $dut.pin(:pinx).add_function :tdi, direction: :input, configuration: :user
      $dut.pin(:piny).add_function :tdo, direction: :output, configurations: :all

      $dut.pin(:pinx).name.should == :pinx
      $dut.pin(:pinx).direction.should == :io
      $dut.pin(:piny).name.should == :tdo
      $dut.pin(:piny).direction.should == :output

      $dut.configuration = :user
      $dut.pin(:pinx).name.should == :tdi
      $dut.pin(:pinx).direction.should == :input
      $dut.pin(:piny).name.should == :tdo
      $dut.pin(:piny).direction.should == :output

      $dut.configuration = :nvmbist
      $dut.pin(:pinx).name.should == :nvm_fail
      $dut.pin(:pinx).direction.should == :output
      $dut.pin(:piny).name.should == :tdo
      $dut.pin(:piny).direction.should == :output

      # Verify that configurations set at pin level override those at DUT level
      $dut.pin(:pinx).configuration = :user
      $dut.pin(:pinx).name.should == :tdi
      $dut.pin(:pinx).direction.should == :input
    end

    it "configuration attributes are nested within mode attributes" do
      $dut.add_pin :pinx
      $dut.pin(:pinx).add_function :tdi, mode: :user
      $dut.pin(:pinx).add_function :nvm_fail, mode: :nvmbist
      $dut.pin(:pinx).add_function :tdo, mode: :nvmbist, configuration: :cti
      $dut.pin(:pinx).name.should == :pinx
      $dut.mode = :nvmbist
      $dut.pin(:pinx).name.should == :nvm_fail
      $dut.configuration = :cti
      $dut.pin(:pinx).name.should == :tdo
      $dut.mode = nil
      $dut.pin(:pinx).name.should == :pinx
    end

    # SMcG - Pin availability is now only scoped by package
    #it "scoped aliases are generated for functions" do
    #  $dut.add_pin :pinx
    #  $dut.pin(:pinx).add_function :nvm_fail, configuration: :nvmbist
    #  $dut.pin(:pinx).add_function :tdi, mode: :user

    #  $dut.has_pin?(:pinx).should == true
    #  $dut.has_pin?(:nvm_fail).should == false
    #  $dut.has_pin?(:tdi).should == false

    #  $dut.mode = :user
    #  $dut.has_pin?(:pinx).should == true
    #  $dut.has_pin?(:nvm_fail).should == false
    #  $dut.has_pin?(:tdi).should == true

    #  $dut.configuration = :nvmbist
    #  $dut.has_pin?(:pinx).should == true
    #  $dut.has_pin?(:nvm_fail).should == true
    #  $dut.has_pin?(:tdi).should == true
    #end

    it "function attributes for a specific config can be extracted" do
      pin = $dut.add_pin :pinx
      $dut.pin(:pinx).add_function_attributes option: "blah1", mode: :nvmbist
      $dut.pin(:pinx).add_function_attributes option: "blah2", mode: :nvmbist, configuration: :cti
      pin.option.should == nil
      pin.option(mode: :nvmbist).should == "blah1"
      pin.option(mode: :nvmbist, configuration: :cti).should == "blah2"
    end
  end

  it "pin direction is sanitized" do
    pin = $dut.add_pin :pinx, direction: "O"
    pin.add_function_attributes direction: "I/O", mode: :nvmbist
    pin.direction.should == :output
    pin.direction(mode: :nvmbist).should == :io
    pin.direction = "I"
    pin.direction.should == :input
    pin.direction = "IO"
    pin.direction.should == :io
  end

  describe "power supplies and grounds" do

    it "power pins can be added" do
      $dut.add_pin :pinx
      $dut.add_pin :piny
      vdd0 = $dut.add_power_pin :vdd0
      $dut.pins.size.should == 2
      $dut.power_pins.size.should == 1
      $dut.power_pins(:vdd0).should == vdd0
      $dut.power_pins(:vdd0).voltage = 3
      $dut.power_pins(:vdd0).voltage.should == 3
      $dut.power_pins(:vdd0).voltage = [1.2,2.5]
      $dut.power_pins(:vdd0).voltage.should == [1.2,2.5]
      $dut.power_pins(:vdd0).voltages.should == [1.2,2.5]
    end

    it "power pin data can be set at instantiation time" do
      $dut.add_power_pin :vdd0, voltage: 5, current_limit: 10.uA, meta: { irange: (5..10) }
      $dut.add_power_pin :vdd1, voltages: [1,2]
      $dut.power_pins(:vdd0).voltage.should == 5
      $dut.power_pins(:vdd0).voltages.should == [5]
      $dut.power_pins(:vdd1).voltages.should == [1,2]
      $dut.power_pins(:vdd0).current_limit.should == 10.uA
      $dut.power_pins(:vdd0).meta[:irange].should == (5..10)
    end

    it "power pin groups can be added" do
      $dut.add_power_pin(:vdd1)
      $dut.add_power_pin(:vdd2)
      $dut.add_power_pin(:vdd3)
      $dut.add_power_pin_group :vdd, :vdd1, :vdd2, package: :p1
      $dut.add_power_pin_group :vdd, :vdd1, :vdd2, :vdd3, package: :p2
      $dut.power_pins.size.should == 3
      $dut.power_pin_groups.size.should == 0
      $dut.power_pin_groups(package: :p1).size.should == 1
      $dut.package = :p1
      $dut.power_pins(:vdd).size.should == 2
      $dut.power_pin_groups.size.should == 1
      $dut.package = :p2
      $dut.power_pins(:vdd).size.should == 3
      $dut.power_pin_groups.size.should == 1
    end

    it "ground pins can be added" do
      $dut.add_pin :pinx
      $dut.add_pin :piny
      gnd0 = $dut.add_ground_pin :gnd0
      $dut.pins.size.should == 2
      $dut.ground_pins.size.should == 1
      $dut.ground_pins(:gnd0).should == gnd0
    end

    it "ground pin groups can be added" do
      $dut.add_ground_pin(:gnd1)
      $dut.add_ground_pin(:gnd2)
      $dut.add_ground_pin(:gnd3)
      $dut.add_ground_pin_group :gnd, :gnd1, :gnd2, package: :p1
      $dut.add_ground_pin_group :gnd, :gnd1, :gnd2, :gnd3, package: :p2
      $dut.ground_pins.size.should == 3
      $dut.ground_pin_groups.size.should == 0
      $dut.ground_pin_groups(package: :p1).size.should == 1
      $dut.ground_pin_groups(:gnd, package: :p1).size.should == 2
      $dut.package = :p1
      $dut.ground_pins(:gnd).size.should == 2
      $dut.ground_pin_groups.size.should == 1
      $dut.package = :p2
      $dut.ground_pins(:gnd).size.should == 3
      $dut.ground_pin_groups.size.should == 1
    end

  end

  describe "virtual pins" do

    it "virtual pins can be added" do
      $dut.add_pin :pinx
      $dut.add_pin :piny
      virtual0 = $dut.add_virtual_pin(:virtual0, type: :virtual_bit)
      $dut.add_virtual_pin(:virtual1, type: :virtual_bit)
      $dut.add_virtual_pin(:virtual2, type: :ate_ch)
      $dut.pins.size.should == 2
      $dut.virtual_pins.size.should == 3
      $dut.virtual_pins(:virtual0).should == virtual0
      $dut.virtual_pins(:virtual0).type = :virtual_bit
      $dut.virtual_pins(:virtual2).type = :ate_ch
    end

    it "virtual pin groups can be added" do
      $dut.add_virtual_pin(:virtual1, type: :virtual_bit)
      $dut.add_virtual_pin(:virtual2, type: :virtual_bit)
      $dut.add_virtual_pin(:virtual3, type: :ate_ch)
      $dut.add_virtual_pin_group :virtual, :virtual1, :virtual2, package: :p1
      $dut.add_virtual_pin_group :virtual, :virtual1, :virtual2, :virtual3, package: :p2
      $dut.virtual_pins.size.should == 3
      $dut.virtual_pin_groups.size.should == 0
      $dut.virtual_pin_groups(package: :p1).size.should == 1
      $dut.package = :p1
      $dut.virtual_pins(:virtual).size.should == 2
      $dut.virtual_pin_groups.size.should == 1
      $dut.package = :p2
      $dut.virtual_pins(:virtual).size.should == 3
      $dut.virtual_pin_groups.size.should == 1
    end

  end

  
  describe "other pins" do
  
    it "other pins can be added" do
      $dut.add_pin :pinx
      $dut.add_pin :piny
      other0 = $dut.add_other_pin(:other0)
      $dut.add_other_pin(:other1)
      $dut.add_other_pin(:other2)
      $dut.pins.size.should == 2
      $dut.other_pins.size.should == 3
      $dut.other_pins(:other0).should == other0
    end
  
    it "other pin groups can be added" do
      $dut.add_other_pin(:other1)
      $dut.add_other_pin(:other2)
      $dut.add_other_pin(:other3)
      $dut.add_other_pin_group :other, :other1, :other2, package: :p1
      $dut.add_other_pin_group :other, :other1, :other2, :other3, package: :p2
      $dut.other_pins.size.should == 3
      $dut.other_pin_groups.size.should == 0
      $dut.other_pin_groups(package: :p1).size.should == 1
      $dut.package = :p1
      $dut.other_pins(:other).size.should == 2
      $dut.other_pin_groups.size.should == 1
      $dut.package = :p2
      $dut.other_pins(:other).size.should == 3
      $dut.other_pin_groups.size.should == 1
      $dut.has_other_pin?(:other).should == true
      $dut.has_other_pin?(:other5).should == false
    end
  
  end

  
  it "driving or asserting nil is the same as 0" do
    pin = $dut.add_pin :pinx
    pin.drive(1)
    pin.value.should == 1
    pin.drive(nil)
    pin.value.should == 0
    pin.assert(1)
    pin.value.should == 1
    pin.assert(nil)
    pin.value.should == 0
  end

  it "pin names (the name that will appear in the pattern) can be set" do
    pin = $dut.add_pin :pinx
    pin.name.should == :pinx
    # The current pin function name will be use in preference to the pin name
    pin.add_function :nvm_done, mode: :nvmbist
    pin.name(mode: :nvmbist).should == :nvm_done
    pin.name.should == :pinx
    $dut.mode = :nvmbist
    pin.name.should == :nvm_done
    # Except when a name is specifically stated
    pin.name =  :done
    pin.name.should == :done
    # Or when a specific context is supplied bypass the default
    pin.name(mode: :nvmbist).should == :nvm_done
  end

  it "deletes all mode, packages, and pins" do
    $dut.add_pin :pinx
    $dut.add_pin :piny
    $dut.modes.should == [:m1, :m2, :user, :nvmbist]
    $dut.packages.should == [:p1, :p2]
    $dut.pins.size.should == 2
    $dut.delete_pin(:piny)
    $dut.pins.size.should == 1
    $dut.pins(:pinx).delete!
    $dut.pins.size.should == 0
    $dut.add_pin :pin1
    $dut.add_pin :pin2
    $dut.add_pin :pin3
    $dut.add_pin_group :g1, :pin1, :pin2
    $dut.add_pin_group :g2, :pin1, :pin2, :pin3
    $dut.pin_groups.size.should == 2
    $dut.delete_pin(:g1)
    $dut.pin_groups.size.should == 1
    $dut.pins(:pin3).delete!
    $dut.pins(:g2).size.should == 2
    $dut.pins(:g2).delete!
    $dut.pin_groups.size.should == 0
    $dut.modes.should == [:m1, :m2, :user, :nvmbist]
    $dut.packages.should == [:p1, :p2]
    $dut.delete_all_modes
    $dut.modes.should == []
    $dut.delete_all_packages
    $dut.packages.should == []
    $dut.delete_all_pins
    $dut.pins.size.should == 0
  end

  it "lists pins within a pin group alphanumerically" do
    $dut.add_pin :pin1
    $dut.add_pin :pin2
    $dut.add_pin :pin3
    $dut.add_pin_group :g2, :pin3, :pin2, :pin1
    $dut.pins(:g2).pins.first.should == :pin1
  end

  it "new attributes can be read and written" do
    $dut.add_pin :pin1
    $dut.add_pin :pin2
    $dut.pins(:pin1).type = :analog
    $dut.pins(:pin2).type = :digital
    $dut.pins(:pin1).type.should == :analog
    $dut.pins(:pin2).type.should == :digital
    $dut.pins(:pin1).type.should_not == $dut.pins(:pin2).type
    $dut.pins(:pin1).ext_pullup = true
    $dut.pins(:pin1).ext_pulldown = false
    $dut.pins(:pin1).open_drain = false
    $dut.pins(:pin1).ext_pullup.should == true
    $dut.pins(:pin1).ext_pulldown.should == false
    $dut.pins(:pin1).open_drain.should == false
    $dut.pins(:pin2).supply = :vdd
    $dut.pins(:pin2).supply.should == :vdd
  end

  it "describe separates functions from simple aliases" do
    $dut.add_pin :pinx
    $dut.pin(:pinx).add_function :nvm_fail, direction: :output, mode: :nvmbist
    $dut.pin(:pinx).add_function :tdi, direction: :input, mode: :user
    $dut.add_pin_alias :dumb_alias, :pinx
    $dut.pin(:pinx).describe(return: true).should == [
      "********************",
      "Pin id: pinx",
      "",
      "Functions",
      "---------",
      ":nvm_fail                     :modes => [:nvmbist]",
      ":tdi                          :modes => [:user]",
      "",
      "Aliases",
      "-------",
      ":dumb_alias                   ",
      "",
      "Modes", 
      "-------",
      "********************"
    ]
  end

  it "pins found via a function name are wrapped by a context" do
    $dut.add_pin :pin1
    $dut.pin(:pin1).add_function :nvm_fail, direction: :output, mode: :nvmbist
    $dut.pin(:pin1).add_function :tdi, direction: :input, mode: :user
    nvm_fail = $dut.pin(:nvm_fail)
    tdi = $dut.pin(:tdi)
    nvm_fail.direction.should == :output
    tdi.direction.should == :input
  end

  it "function name ids used when defining groups are applied to the pins" do
    $dut.add_pin :pin1
    $dut.add_pin :pin2
    # Define some mode specific pin functions in the normal way
    $dut.pin(:pin1).add_function :nvm_fail, direction: :output
    $dut.pin(:pin2).add_function :nvm_done, direction: :output
    $dut.pin(:pin1).add_function :tdi, direction: :input
    $dut.pin(:pin2).add_function :tdo, direction: :output
    $dut.pin(:nvm_fail).direction.should == :output
    $dut.pin(:nvm_done).direction.should == :output
    $dut.pin(:tdi).direction.should == :input
    $dut.pin(:tdo).direction.should == :output
    # Create some groups and define an associated mode context
    $dut.add_pin_group :jtag, :tdi, :tdo, mode: :user
    $dut.add_pin_group :nvm,  :nvm_fail, :nvm_done, mode: :nvmbist

    $dut.pins(:jtag)[0].direction.should == :output
    $dut.pins(:jtag)[1].direction.should == :input
    $dut.pins(:nvm)[0].direction.should == :output
    $dut.pins(:nvm)[1].direction.should == :output
  end

  describe "Issue Fixes for Pins" do
    it "#69 ::: pins groups can be composed of standalone pins and other groups" do
      $dut.add_pin(:tdi)
      $dut.add_pin(:tdo)
      $dut.add_pin(:tclk)
      $dut.add_pin(:tms)
      $dut.add_pins(:porta, size: 8)
      $dut.add_pins(:portb, size: 16)
    
      $dut.pins.size.should == 28
      $dut.add_pin_group :jtag, :tdi, :tdo, :tclk, :tms
      $dut.add_pin_group :ports, :porta, :portb
      $dut.add_pin_group :all, :tdi, :tdo, :tclk, :tms, :porta, :portb
      $dut.add_pin_group :all2, :jtag, :ports
    
      $dut.pins(:jtag).size.should == 4
      $dut.pins(:ports).size.should == 24
      $dut.pins(:all).size.should == 28
      $dut.pins(:all2).size.should == 28
    end
  end
  
  it "pin meta data can be found via method meissing and respond_to?" do
    $dut.add_pin :pinx, meta: { a: 2 }
    $dut.pins(:pinx).meta[:a].should == $dut.pins(:pinx).a
    $dut.pins(:pinx).respond_to?(:a).should == true
  end
  
  it 'add DIB metadata based on package scope' do
    $dut.add_package :pcs
    $dut.add_package :bga
    $dut.add_pin :tdo, packages: { bga: { location: 'BF32', dib_assignment: [10104] }, pcs: { location: 'BF30', dib_assignment: [31808] } }
    $dut.pins(:tdo).add_dib_meta :pcs, { :x=>2000, :y=>-15600, :net_name=>"R92/DUT_TDO_TC", :connection=>"PE118.16", :slot=>"PE118", :spring_pin=>"16" }
    $dut.pins(:tdo).add_dib_meta :bga, { :x=>2000.0, :y=>-15600.0, :net_name=>"TDO", :connection=>"PE117.08", :slot=>"PE117", :spring_pin=>"08" }
    $dut.package = nil
    $dut.pins(:tdo).dib_meta.should == {}
    $dut.package = :bga
    $dut.pins(:tdo).dib_meta.should == { :x=>2000.0, :y=>-15600.0, :net_name=>"TDO", :connection=>"PE117.08", :slot=>"PE117", :spring_pin=>"08" }
    $dut.package = :pcs
    $dut.pins(:tdo).dib_meta.should == { :x=>2000, :y=>-15600, :net_name=>"R92/DUT_TDO_TC", :connection=>"PE118.16", :slot=>"PE118", :spring_pin=>"16" }
  end
  
  it 'does not allow user to set the current DUT package unless it is to a known package' do
    Origen.app.unload_target!
    @dut = IncorrectPackageDut.new
    @dut.packages.should == []
    @dut.package = :bga # This used to be allowed, setting the package to an unknown package ID
    @dut.has_pin?(:pinx).should == true # and would then raise an exception when trying to access any pin
    @dut.add_packages
    @dut.package = :pcs
    @dut.package.id.should == :pcs
    @dut.has_pin?(:pinx).should == false
  end
end
