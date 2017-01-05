require "spec_helper"

describe "Pin timing API" do

  before :each do
    Origen.target.temporary = -> do
      PinTimingTop.new
    end
    Origen.target.load!
  end

  class PinTimingTop
    include Origen::TopLevel

    def initialize
      add_pin :tck
      add_pin :tdi
      add_pin :tdo
      add_pin :tms
      add_pins :gpio, size: 16

      # Simple definition, all pins have default waves
      add_timeset :t1

      # Complex definition, defines an alternative default compare
      # wave and specific timing for :tck
      timeset :func do |t|
        #t.compare do |w|

        #end

        #t.drive :tck do |w|

        #end
      end


    end
  end

  it "testbench is alive" do
    dut.is_a?(PinTimingTop).should == true
  end

  it "the timesets can be accessed directly" do
    dut.timesets.size.should == 2
    # With no args should return the current, which is not set yet
    dut.timeset.should == nil
    dut.current_timeset.should == nil
    # Test the various ways of accessing specific timesets
    dut.timesets[:t1].id.should == :t1
    dut.timesets(:t1).id.should == :t1
    dut.timeset(:t1).id.should == :t1
  end



end
