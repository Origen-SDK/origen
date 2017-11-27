require 'spec_helper'

describe Symbol do

  specify 'shortcut for matching works' do
    sym = :ddr1_controller
    sym.smatch(/^ddr(\d)\_/)[1].should == '1'
  end
end
