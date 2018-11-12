require "spec_helper"

describe "Feature API" do

  it "feature object creation and core methods test" do
    class DUT
      include Origen::Features
      feature :feature1
      feature :feature2, description: "feature2 description"
      # This is feature 3 description
      # more feature3 description
      feature :feature3
      feature :feature4
    end

    dut = DUT.new
    dut.has_features?.should == true
    dut.has_feature?(:feature1).should == true
    dut.has_features?(:feature5).should == false

    dut.features.should == [:feature1, :feature2, :feature3, :feature4]
    dut.features.include?(:feature4).should == true
    
    dut.feature(:feature2).describe.should == "feature2 description"
    dut.feature(:feature3).describe.should == "This is feature 3 description more feature3 description"
    dut.feature(:feature4).describe.should == "No description provided!"

    dut.feature(:feature3).description.should == ["This is feature 3 description","more feature3 description"]
    dut.feature(:feature4).description.should == []

  end

  class Test_NVM
    include Origen::Features
    include Origen::Registers
    feature :f1, description: "f1 description"
    feature :f2

    def analog
      @analog ||= Analog.new(self)
    end

    def initialize
      reg :r1, 10, 16 do
        bits 0..15, :data
      end
      reg :r2, 20, feature: :f1 do
        bits 3..0, :data
      end
      reg :r3, 30, feature: :f3 do
        bits 15..0, :dataLow
        bits 31..16, :dataHigh
      end
      reg :r4, 40 do
        bits 15..0, :dataLow
        bits 31..16, :dataHigh, feature: :f2
      end
      reg :r5, 50, feature: :f2 do
        bits 1..31, :data
        bit 0, :bit0, feature: :f1
      end
      reg :r6, 40 do
        bits 15..0, :dataLow
        bits 31..16, :dataHigh, feature: :f3
      end
      reg :r7, 60, feature: [:f3, :f4] do
        bits 31..0, :data
      end
    end
  end
  
  it "quering for registers' set" do
    dut = Test_NVM.new
    dut.has_features?.should == true
    dut.has_feature?(:f1).should == true
    dut.regs.size.should == 5
    dut.regs(enabled_features: :all).size.should == 7
    dut.regs(enabled_features: :default).size.should == 5
    dut.regs(enabled_features: :f1).size.should == 4
    dut.regs(enabled_features: [:f1, :f2, :f3]).size.should == 7
    dut.regs(enabled_features: :f3).size.should == 5
    dut.regs(enabled_features: :f4).size.should == 4
    dut.regs(enabled_features: :none).size.should == 3
  end
  
  it "quering for bits' set" do
  
    dut = Test_NVM.new
    dut.reg(:r1).bits.size.should == 16
    dut.reg(:r1).bits(enabled_features: :none).size.should == 16
    
    dut.reg(:r4).bits(enabled_features: :none).size.should == 32
    dut.reg(:r4).bits(enabled_features: :f1).size.should == 32
    dut.reg(:r4).bits(enabled_features: :f2).size.should == 32
    dut.reg(:r4).bits(enabled_features: :default).size.should == 32

    dut.reg(:r5).bit(0).size.should == 1

    dut.reg(:r6).bits(enabled_features: :all).size.should == 32
    dut.reg(:r6).bits(enabled_features: [:f1, :f2]).size.should == 32
    dut.reg(:r6).bits(enabled_features: :f1).size.should == 32

    dut.reg(:r6).bits(:dataHigh).write(0x1234)
    dut.reg(:r6).bits(:dataHigh).data.should == 0

    dut.reg(:r6).bits(:dataLow).write(12345)
    dut.reg(:r6).bits(:dataLow).data.should == 12345
    dut.reg(:r6).bits.write(0x1234_5678)
    dut.reg(:r6).data.should == 22136 # decimal of 0x5678

    dut.reg :data_reg, 25, feature: :f3 do |reg|
      reg.bit 0, :b0, feature: [:f1, :f2]
      reg.bit 4, :b1
      reg.bit 9, :b2
    end
    dut.reg(:data_reg, enabled_features: :f3).bit(:b0, enabled_features: [:f3]).enabled?.should == false
  end

  it "quering for specific register" do
  
    dut = Test_NVM.new
    dut.reg(:r1).has_feature_constraint?.should == false
    dut.reg(:r2).has_feature_constraint?.should == true    
    dut.reg(:r3, enabled_feature: :f3).has_feature_constraint?.should == true
    dut.reg(:r5, enabled_features: :none).should == nil # this should give an error
    dut.reg(:r3).should == nil
    dut.reg(:r5).enabled_by_feature?(:f2).should == true
    dut.reg(:r7, enabled_feature: :f3).has_feature_constraint?.should == true
    dut.reg(:r7, enabled_feature: :f3).enabled_by_feature?(:f3).should == true
    dut.reg(:r7, enabled_feature: :f3).enabled_by_feature?(:f4).should == true
    dut.reg(:r7, enabled_feature: [:f3, :f4]).enabled_by_feature?(:f3).should == true
    dut.reg(:r7, enabled_feature: [:f3, :f4]).enabled_by_feature?(:f4).should == true
    dut.reg(:r7).should == nil
    dut.reg(:r5).enabled?.should == true

    dut.reg(:r3, enabled_features: :all).enabled?.should == false

  end

  it "quering for specific bits" do
  
    dut=Test_NVM.new
    reg = dut.reg(:r1)

    reg.bits(enabled_features: :all).features.should == nil
    reg.bits(:data).has_feature_constraint?.should == false
    reg.bits(:data).enabled_by_feature?(:f1).should == false
    reg = dut.reg(:r2)
    reg.bits.features.should == nil
    reg.bits(:data).has_feature_constraint?.should == false
    reg = dut.reg(:r3, enabled_features: :all)
    reg.bits(:dataHigh).has_feature_constraint?.should == false
    reg.bits(:dataLow).has_feature_constraint?.should == false
    reg.bits(:dataHigh).enabled_by_feature?(:f2).should == false
    reg.bits.features.should == nil
    dut.reg(:r4).bits.features.should == :f2

  end

  it "checking if bit or register is enabled or not" do
    dut = Test_NVM.new
    dut.reg(:r1).enabled?.should == true
    dut.reg(:r2).enabled?.should == true
    dut.reg(:r3, enabled_features: :f3).enabled?.should == false
    dut.reg(:r4).enabled?.should == true
    dut.reg(:r5).enabled?.should == true
    dut.reg(:r1).bits(:data).enabled?.should == true
    dut.reg(:r4).bits(:dataHigh).enabled?.should == true
    dut.reg(:r4).bits(:dataHigh, enabled_feature: :default).enabled? == true
    dut.reg(:r5).bit(:bit0).enabled?.should == true
    dut.reg(:r5).bits(:data).enabled?.should == true
    dut.reg(:r6).bits(:dataHigh, enabled_feature: :f3).enabled?.should == false
    dut.reg(:r6).bits(:dataHigh, enabled_features: :all).enabled?.should == false

  end

  it "testing case when owner's owner has enabled the feature" do
    class Analog
      include Origen::Features
      include Origen::Registers
      
      feature :analog_feat1
      feature :analog_feat2
      
      def owner
        @owner
      end

      def initialize(owner)
        @owner = owner
      end

      def analog_registers
        reg :analog_reg, 60, feature: :analog_feat1 do
          bits 1..15, :data, feature: :analog_feat2
          bit 0, :flag, feature: :f1
        end
      end
    end
    
    dut1 = Test_NVM.new
    analog_block = dut1.analog    
    analog_block.analog_registers
    analog_block.reg(:analog_reg).bit(:flag).enabled?.should == true
  end

end

