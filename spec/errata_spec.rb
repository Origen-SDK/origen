require "spec_helper"

# Dummy classes to test out the errata module
class SoCWithErrata
  include Origen::Model

  def initialize
    erratum("ERR1", "ddr", {title: "Feature A is broken", description: "Feature A is broken because of B", hw_workaround_description: "Feature A cannot be fixed in hardware"}, {disposition: "external", impact: "Feature A can only be used this way", fix_plan: "Feature A will not be fixed in hardware"}, sw_workaround("SW1", {title: "Workaround for Feature A", description: "This is how Feature A is fixed", sw_disposition: "Available", distribution: "SDK1"}, {note: "Release note for workaround", patches: "www.patch.com/1"}))
    erratum("ERR2", "usb", {title: "Feature C is broken", description: "Feature C is broken because of D", hw_workaround_description: "Feature C cannot be fixed in hardware"}, {disposition: "internal", impact: "Feature C can only be used this way", fix_plan: "Feature C will not be fixed in hardware"}, sw_workaround("SW2", {title: "Workaround for Feature C", description: "This is how Feature C is fixed", sw_disposition: "Not Available", distribution: "SDK2"}, {note: "Release note for workaround", patches: "www.patch.com/2"}))
    erratum("ERR3", "ddr", {title: "Feature A is broken", description: "Feature A is broken because of B", hw_workaround_description: "Feature A cannot be fixed in hardware"}, {disposition: "external", impact: "Feature A can only be used this way", fix_plan: "Feature A will not be fixed in hardware"}, sw_workaround("SW3", {title: "Workaround for Feature A", description: "This is how Feature A is fixed", sw_disposition: "Available", distribution: "SDK1"}, {note: "Release note for workaround", patches: "www.patch.com/1"}))


    sw_workaround("SW4")
    sw_workaround("SW5")
  end
end

describe "Origen Errata Module" do
  before :all do
    @dut = SoCWithErrata.new
   end

  it "Errata objects are created" do
    @dut.errata.size.should == 3
    @dut.errata.class.should == Hash
  end

  it "All HwErratum class variables are initialized and can be accessed" do
    @dut.errata(id: "ERR1").id.should == "ERR1"
    @dut.errata(id: "ERR1").ip_block.should == "ddr"
    @dut.errata(id: "ERR1").title.should == "Feature A is broken"
    @dut.errata(id: "ERR1").description.should == "Feature A is broken because of B"
    @dut.errata(id: "ERR1").hw_workaround_description.should == "Feature A cannot be fixed in hardware"
    @dut.errata(id: "ERR1").disposition.should == "external"
    @dut.errata(id: "ERR1").impact.should == "Feature A can only be used this way"
    @dut.errata(id: "ERR1").fix_plan.should == "Feature A will not be fixed in hardware"
  end

  it "All SwErratumWorkaround class variables are initialized and can be accessed" do
    @dut.errata(id: "ERR1").sw_workaround.is_a?(Origen::Errata::SwErratumWorkaround).should == true
    @dut.errata(id: "ERR1").sw_workaround.id.should == "SW1"
    @dut.errata(id: "ERR1").sw_workaround.title.should == "Workaround for Feature A"
    @dut.errata(id: "ERR1").sw_workaround.description.should == "This is how Feature A is fixed"
    @dut.errata(id: "ERR1").sw_workaround.sw_disposition.should == "Available"
    @dut.errata(id: "ERR1").sw_workaround.distribution.should == "SDK1"
    @dut.errata(id: "ERR1").sw_workaround.note.should == "Release note for workaround"
    @dut.errata(id: "ERR1").sw_workaround.patches.should == "www.patch.com/1"
  end

  it "Errata function returns object with specific ID" do
    @dut.errata(id: "ERR1").is_a?(Origen::Errata::HwErratum).should == true
    @dut.errata(id:"ERR1").id.should == "ERR1"
  end
  
  it "Software workaround can be created" do
    @dut.sw_workarounds.size.should == 5
    @dut.sw_workarounds.all? {|name, sw_wa| sw_wa.is_a?(Origen::Errata::SwErratumWorkaround)}.should == true
  end
 
  it "Can access all errata from one IP block" do
    @dut.errata(ip_block: "ddr").size.should == 2
    @dut.errata(ip_block: "ddr").class.should == Hash
    @dut.errata(ip_block: "usb").is_a?(Origen::Errata::HwErratum).should == true
    @dut.errata(ip_block: "test").nil?.should == true
  end
  
  it "Can access all errata of one disposition" do
    @dut.errata(disposition: "external").size.should == 2
    @dut.errata(disposition: "external").class.should == Hash
    @dut.errata(disposition: "internal").is_a?(Origen::Errata::HwErratum).should == true
  end
 
  it "Can filter errata on multiple parameters" do
    @dut.errata(ip_block: "ddr", disposition: "external").size.should == 2
    @dut.errata(ip_block: "usb", disposition: "internal").class.should == Origen::Errata::HwErratum
    @dut.errata(ip_block: "ddr", disposition: "internal").nil?.should == true
  end
end 
