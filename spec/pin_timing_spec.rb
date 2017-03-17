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
        t.wave do |w|
          w.compare :data, at: "period / 4"
        end

        t.wave :tck do |w|
          w.drive :data, at: 0
          w.drive 0, at: 25
          w.dont_care at: "period - 10"
        end
      end

      # Another timeset to test the wave assignment to pin groups
      timeset :t2 do |t|
        t.wave :gpio5 do |w|
          w.compare :data, at: 100
        end

        t.wave :gpio do |w|
          w.drive :data, at: 200
        end
      end
    end
  end

  it "testbench is alive" do
    dut.is_a?(PinTimingTop).should == true
  end

  it "the timesets can be accessed directly" do
    dut.timesets.size.should == 3
    # With no args should return the current, which is not set yet
    dut.timeset.should == nil
    dut.current_timeset.should == nil
    # Test the various ways of accessing specific timesets
    dut.timesets[:t1].id.should == :t1
    dut.timesets(:t1).id.should == :t1
    dut.timeset(:t1).id.should == :t1
  end

  it "the current timeset can be set" do
    dut.timeset.should == nil
    dut.current_timeset.should == nil
    dut.timeset = :t1
    dut.timeset.id.should == :t1
    dut.current_timeset.id.should == :t1
    dut.current_timeset = :func
    dut.timeset.id.should == :func
    dut.current_timeset.id.should == :func
  end

  it "the timesets have default waves" do
    dut.timeset(:t1).drive_waves.size.should == 1
    dut.timeset(:t1).compare_waves.size.should == 1
    dut.timeset(:t1).drive_waves[0].events.size.should == 1
    dut.timeset(:t1).drive_waves[0].events[0].should == [0, :data]
    dut.timeset(:t1).compare_waves[0].events.size.should == 1
    dut.timeset(:t1).compare_waves[0].events[0].should == ["period / 2", :data]
  end

  it "the default waves can be overridden" do
    t = dut.timeset(:func)
    t.drive_waves.size.should == 2
    t.compare_waves.size.should == 1
    t.compare_waves[0].events[0].should == ["period / 4", :data]
  end

  it "the dut pins associated with each waveform can be accessed" do
    # All pins should be assigned in the default timeset case
    dut.timeset(:t1).drive_waves[0].pins.size.should == 20
    dut.timeset(:t1).compare_waves[0].pins.size.should == 20
    dut.timeset(:func).drive_waves[0].pins.size.should == 19
    dut.timeset(:func).drive_waves[1].pins.size.should == 1
    dut.timeset(:func).drive_waves[1].pins[0].id.should == :tck
    dut.timeset(:func).compare_waves[0].pins.size.should == 20
  end

  it "the wave can be accessed via the pin" do
    dut.pin(:tck).drive_wave.should == nil
    dut.timeset = :t1
    dut.pin(:tck).drive_wave.events.size.should == 1
    dut.pin(:tms).compare_wave.events[0].should == ["period / 2", :data]
    dut.timeset = :func
    dut.pin(:tck).drive_wave.events.size.should == 3
    dut.pin(:tms).compare_wave.events[0].should == ["period / 4", :data]
  end

  it "wave assignments work for pin groups" do
    dut.timeset = :t2

    dut.pins(:gpio).each do |pin|
      if pin.id == :gpio5
        pin.compare_wave.events[0][0].should == 100
      else
        pin.compare_wave.events[0][0].should == "period / 2"
      end
      pin.drive_wave.events[0][0].should == 200
    end
  end

  it "evaluated_events calculates the times" do
    dut.timeset = :func
    p = dut.pin(:tck)
    dut.current_timeset_period = 100
    p.drive_wave.events[0].should == [0, :data]
    p.drive_wave.events[1].should == [25, 0]
    p.drive_wave.events[2].should == ["period - 10", :x]
    p.drive_wave.evaluated_events[0].should == [0, :data]
    p.drive_wave.evaluated_events[1].should == [25, 0]
    p.drive_wave.evaluated_events[2].should == [90, :x]
  end
end
