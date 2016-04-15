require "spec_helper"

# Dummy classes to test out the errata module
class SoCWithErrata
  include Origen::Model

    #erratum ("ERR1", {:title => "SoC feature is broken", :description => "There is a problem with this feature on the SoC", :hw_workaround_description =>"This feature cannot be fixed in hardware"}, {:disposition => "External", :impact => "Patch must be applied to use this feature", :fix_plan => "No plan to fix"}, sw_workaround("SW1", {:title => "Workaround for ERR1", :description =>  "Fixes the problems in ERR1", :disposition => "Available", :distribution => "SDK1"}, {:note =>"This is a release note", :patches =>"http://nxp.com/patch1"}))
    #erratum("ERR2", {:title =>"Another feature is broken", :description =>"There is an issue with another feature on the SoC", :hw_workaround_description =>"This feature cannot be fixed in hardware"}, {:disposition =>"Internal", :impact =>"Patch must be applied to use this feature", :fix_plan =>"No plan to fix"}, sw_workaround("SW2", {:title =>"Workaround for ERR2", :description =>"Fixes the problems in ERR2", :disposition => "Not Available",:distribution =>"SDK2"}, {:note =>"This is a release note", :patches =>"http://nxp.com/patch2"}))
  def initialize(version)
    erratum("ERR1")
    erratum("ERR2")
    sw_workaround("SW1")
    sw_workaround("SW2")
    #erratum("ERR3", {title: "Feature A is broken", description: "Feature A is broken because B", hw_workaround_description: "Cannot be fixed in hardware"})
    @version = version
  end
end

describe "Origen Errata Module" do
  before :all do
    @dut = SoCWithErrata.new(0)
   end

  it "Errata objects are created" do
    @dut.errata.size.should == 2
    @dut.errata.all? {|name, erratum| erratum.is_a?(Origen::Errata::HwErratum)}.should == true
  end

  it "Errata API returns object with specific ID" do
    @dut.errata(id: "ERR1").is_a?(Origen::Errata::HwErratum).should == true
    @dut.errata(id:"ERR1").id.should == "ERR1"
  end
  
  it "Software workaround can be created" do
    @dut.sw_workarounds.size.should == 2
    @dut.sw_workarounds.all? {|name, sw_wa| sw_wa.is_a?(Origen::Errata::SwErratumWorkaround)}.should == true
  end
 
  it "Erratum Object can be initialized" do
    @dut.erratum("ERR3", {title: "Feature A is broken", description: "Feature A is broken because B", hw_workaround_description: "Cannot be fixed in hardware"}, {disposition: "External", impact: "Feature A can only be used in this way", fix_plan: "No plans to fix"}, ["ddr", "serdes"],@dut.sw_workarounds(id: "SW1")).is_a?(Origen::Errata::HwErratum).should == true
  end

  it "Sw workaround can be accessed from Erratum" do
    @dut.errata(id: "ERR3").sw_workaround.is_a?(Origen::Errata::SwErratumWorkaround).should == true
  end
end 
