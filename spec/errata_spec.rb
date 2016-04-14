require "spec_helper"

# Dummy classes to test out the errata module
class SoCWithErrata
  include Origen::Model

  #def initialize(version)
  #("ERR1")
  #erratum("ERR1")
    #erratum ("ERR1", {:title => "SoC feature is broken", :description => "There is a problem with this feature on the SoC", :hw_workaround_description =>"This feature cannot be fixed in hardware"}, {:disposition => "External", :impact => "Patch must be applied to use this feature", :fix_plan => "No plan to fix"}, sw_workaround("SW1", {:title => "Workaround for ERR1", :description =>  "Fixes the problems in ERR1", :disposition => "Available", :distribution => "SDK1"}, {:note =>"This is a release note", :patches =>"http://nxp.com/patch1"}))
    #erratum("ERR2", {:title =>"Another feature is broken", :description =>"There is an issue with another feature on the SoC", :hw_workaround_description =>"This feature cannot be fixed in hardware"}, {:disposition =>"Internal", :impact =>"Patch must be applied to use this feature", :fix_plan =>"No plan to fix"}, sw_workaround("SW2", {:title =>"Workaround for ERR2", :description =>"Fixes the problems in ERR2", :disposition => "Not Available",:distribution =>"SDK2"}, {:note =>"This is a release note", :patches =>"http://nxp.com/patch2"}))
  def initialize(version)
    erratum("ERR1")
    erratum("ERR2")
    @version = version
  end
end

describe "Origen Errata Module" do
  #before :all do
  #  @dut = SoCWithErrata.new(1)
  #end

  it "Errata objects are created" do
    @dut = SoCWithErrata.new(0)
    #Origen.load_target("configurable", dut: SoCWithErrata, version: 0)
    @dut.errata().size.should == 2
    # @dut.errata("ERR1").class.should == Origen::Errata::Hw_Erratum
    @dut.errata.all? {|name, erratum| erratum.is_a?(Origen::Errata::HwErratum)}.should == true
  end
    
end 
