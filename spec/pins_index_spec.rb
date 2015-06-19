require "spec_helper"

class PinsDutIndex
  include RGen::TopLevel
end

describe "RGen Pin/Port Names " do

  before :each do
    RGen.load_target("configurable", dut: PinsDutIndex)
  end

  it "checks portid with no index in the name works" do
    pname = "portid"
    RGen.top_level.add_port pname.to_sym, :size => 2
    pin = RGen.top_level.pin(pname.to_sym)
    pin.vector_formatted_value = "11"
    $tester.current_pin_vals.should == "11"
  end
  it "checks portid with index in the name works" do
    pname = "port1id"
    RGen.top_level.add_port pname.to_sym, :size => 2
    pin = RGen.top_level.pin(pname.to_sym)
    pin.vector_formatted_value = "11"
    $tester.current_pin_vals.should == "11"
  end

  it "checks port name ending in integer works myport1" do
    pname = "myport1"
    RGen.top_level.add_port pname.to_sym, :size => 10
    pin = RGen.top_level.pin(pname.to_sym)
    pin.vector_formatted_value = "1111100000"
    $tester.current_pin_vals.should == "1111100000"
  end
end
