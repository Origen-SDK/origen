require "spec_helper"

# Some dummy classes to test out the pins module
class PinsDut1
  include Origen::TopLevel
  attr_accessor :sub_module
  def initialize 
    add_pin :pin1
    add_pin_alias :alias1, :pin1
    add_port :jtag,    size: 2
        add_pin_alias :tdo,      :jtag, pin: 1
        add_pin_alias :tdi,      :jtag, pin: 0

    add_pin_alias :nvm_invoke, :tdi
    add_pin_alias :nvm_done, :tdo
    @sub_module = PinsSubModule1.new
  end
end

class PinsSubModule1
  include Origen::Pins
  def initialize
    add_pin :sub_pin1
    add_pin_alias :sub_alias1, :pin1
  end
end

describe "Origen Pins Module" do

  before :all do
    Origen.load_target("configurable", dut: PinsDut1)
  end

  it "has_pin? method works" do
    $dut.has_pin?(:pin1).should == true
    $dut.has_pin?(:alias1).should == true
  end

  it "is_alias_of? method works" do
    $dut.pin(:pin1).is_alias_of?(:alias1).should == true
    $dut.pin(:pin1).is_alias_of?(:alias2).should == false
    $dut.pin(:alias1).is_alias_of?(:pin1).should == true
    $dut.pin(:alias1).is_alias_of?(:pin2).should == false
    $dut.pin(:pin1).is_alias_of?(:sub_alias1).should == true
    $dut.sub_module.pin(:sub_alias1).is_alias_of?(:pin1).should == true
    $dut.sub_module.pin(:sub_alias1).is_alias_of?(:alias1).should == true
    $dut.pin(:nvm_invoke).is_alias_of?(:tdi).should == true
  end

  it "belongs_to_a_port? method works" do
    $dut.pin(:nvm_invoke).belongs_to_a_port?.should == true
    $dut.pin(:tdo).belongs_to_a_port?.should == true
    $dut.pin(:pin1).belongs_to_a_port?.should == false
  end

  it "aliases of port aliases work" do
    $dut.has_pin?(:nvm_invoke).should == true
    $dut.pin(:nvm_invoke)  # Access it to make sure no error
  end

  # This currently fails, need a good real life case of how this should work
  #it "aliases of port aliases work in pattern formatting" do
  #  # This can fail if these alias to the same name (e.g. jtag)
  #  $dut.pin_pattern_order(:tdo, :tdi)
  #  $tester.ordered_pins
  #end

  it "real life issue with duplicate pins in pattern is fixed" do
    class L2K
      include Origen::TopLevel

      def initialize
        add_pin :swd_clk,  reset: :drive_lo
        add_pin :swd_dio,  reset: :drive_hi
        add_pin :pta19,    reset: :drive_lo
        add_pin :resetb,   reset: :drive_hi
        add_pin :extal,    reset: :drive_hi
        add_pin :extal_mx, reset: :drive_hi
        add_pin_alias :nvm_clk,     :extal
        add_pin_alias :nvm_clk_mux, :extal_mx
        add_pin :nvm_invoke,  reset: :drive_lo
        add_pin :nvm_done
        add_pin :nvm_fail
        add_pin :nvm_alvtst
        add_pin :nvm_dtst
        add_pin_alias :nvm_ahvtst, :resetb
        add_pin_alias :nvm_reset, :resetb
        pin(:nvm_done).name = :done
        pin(:nvm_fail).name = :fail
        # Unspecified pins will appear in arbitrary order at the end
        pin_pattern_order :nvm_clk, :nvm_clk_mux, :nvm_invoke, :nvm_done, :nvm_fail,
                          :nvm_alvtst, :nvm_ahvtst, :nvm_dtst
      end
    end
    Origen.load_target("configurable", dut: L2K)

    $tester.cycle
    $tester.ordered_pins.size.should == 11
  end

end
