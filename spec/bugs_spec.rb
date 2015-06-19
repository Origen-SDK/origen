require "spec_helper"

class BugsDut
  include RGen::TopLevel
  attr_reader :version

  bug :low_vref, affected_version: 0
  bug :low_iref, affected_versions: [0, 1]
  bug :dac_code, fixed_on_version: 1
  bug :unfixable

  def initialize(version)
    @version = version
  end
end

describe "Bugs API" do

  after :all do
    RGen.load_target("debug")
  end

  it "bug objects are created" do
    RGen.load_target("configurable", dut: BugsDut, version: 0)
    $dut.bugs.size.should == 4
    $dut.bugs.all? { |name, bug| bug.is_a?(RGen::Bugs::Bug) }.should == true
  end

  it "bug presence methods are generated" do
    RGen.load_target("configurable", dut: BugsDut, version: 0)
    $dut.has_bug?(:low_vref).should == true
    $dut.has_bug?(:low_iref).should == true
    $dut.has_bug?(:dac_code).should == true
    $dut.has_bug?(:unfixable).should == true
    $dut.has_bug?(:undefined).should == false
  end

  it "fixed on version is the one after the last affected version unless specified" do
    RGen.load_target("configurable", dut: BugsDut, version: 0)
    $dut.bugs[:low_iref].fixed_on_version.should == 2
    $dut.bugs[:dac_code].fixed_on_version.should == 1
    $dut.bugs[:unfixable].fixed_on_version.should == nil
  end

  it "bug presence methods scope to the current version" do
    RGen.load_target("configurable", dut: BugsDut, version: 1)
    $dut.has_bug?(:low_vref).should == false
    $dut.has_bug?(:low_iref).should == true
    $dut.has_bug?(:dac_code).should == false
    $dut.has_bug?(:unfixable).should == true
    RGen.load_target("configurable", dut: BugsDut, version: 2)
    $dut.has_bug?(:low_vref).should == false
    $dut.has_bug?(:low_iref).should == false
    $dut.has_bug?(:dac_code).should == false
    $dut.has_bug?(:unfixable).should == true
  end

end
