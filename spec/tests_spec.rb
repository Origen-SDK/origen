require "spec_helper"

# Some dummy classes to test out the Tests module
class SoC_With_Tests
  include Origen::TopLevel

  def initialize
    sub_block :ip_with_tests, class_name: "IP_With_Tests", base_address: 0x1000_0000
    
    add_test :my_test_id do |t|
      t.description = 'my test description'
      t.conditions  = [:minvdd, :maxvdd, :bin1_1300Mhz, :bin2_1200Mhz]
      t.platforms   = [:v93k]
      t.meta1       = 'dkwew'
      t.meta2       = 'jkjejkf'
    end
    
    add_test :my_test_id_2 do |t|
      t.description = 'my test description 2'
      t.conditions  = [:minvdd, :maxvdd, :bin1_1300Mhz, :bin2_1200Mhz]
      t.platforms   = [:v93k]
      t.meta1       = 'dkwew'
    end
    
    add_test :your_test_id_1 do |t|
      t.description = 'your test description'
      t.conditions  = [:xminvdd, :maxvdd, :bin1_1500Mhz, :bin2_1300Mhz]
      t.platforms   = [:v93k]
      t.meta1       = 'dkwew'
      t.meta2       = 'jkjejkf'
    end
    
  end
  
end

class IP_With_Tests
  include Origen::Model
  
  def initialize
    add_test :sub_block_test_id_1 do |t|
      t.description = 'sub_block test description'
      t.conditions  = [:xminvdd, :maxvdd, :bin1_1500Mhz, :bin2_1300Mhz]
      t.platforms   = [:v93k]
      t.meta1       = 'dkwew'
      t.meta2       = 'jkjejkf'
    end
    
  end
end
    
describe "Tests" do

  before :each do
    Origen.app.unload_target!
    Origen.target.temporary = -> { SoC_With_Tests.new }
    Origen.load_target
  end
  
  after :all do
    Origen.app.unload_target!
  end

  it "can create and interact with top level Tests" do
    dut.tests.should == [:my_test_id, :my_test_id_2, :your_test_id_1]
    dut.tests.size.should == 3
    dut.tests(/my_test/).class.should == Hash
    dut.tests(/my_test/).size.should == 2
    dut.tests(:my_test_id).id.should == :my_test_id
    dut.tests(:my_test_id).name.should == :my_test_id
    dut.tests(:my_test_id).platforms.should == [:v93k]
    dut.tests(:my_test_id).conditions.should == [:minvdd, :maxvdd, :bin1_1300Mhz, :bin2_1200Mhz]
    dut.tests(:my_test_id).meta1.should == 'dkwew'
  end
  
  it "can create and interact with IP level Tests" do
    dut.ip_with_tests.tests.size.should == 1
    dut.ip_with_tests.tests.include?(:my_test_id).should == false
  end
    
end
