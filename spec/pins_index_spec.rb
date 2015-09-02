require "spec_helper"

class PinsDutIndex
  include Origen::TopLevel
end

describe "Origen Pin/Port Names " do

  before :each do
    Origen.load_target("configurable", dut: PinsDutIndex)
  end

  it "checks portid with no index in the name works" do
    pname = "portid"
    Origen.top_level.add_port pname.to_sym, :size => 2
    pin = Origen.top_level.pin(pname.to_sym)
    pin.vector_formatted_value = "11"
    $tester.current_pin_vals.should == "11"
  end

  it "checks portid with index in the name works" do
    pname = "port1id"
    Origen.top_level.add_port pname.to_sym, :size => 2
    pin = Origen.top_level.pin(pname.to_sym)
    pin.vector_formatted_value = "11"
    $tester.current_pin_vals.should == "11"
  end

  it "checks port name ending in integer works myport1" do
    pname = "myport1"
    Origen.top_level.add_port pname.to_sym, :size => 10
    pin = Origen.top_level.pin(pname.to_sym)
    pin.vector_formatted_value = "1111100000"
    $tester.current_pin_vals.should == "1111100000"
  end
end
