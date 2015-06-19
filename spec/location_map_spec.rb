require 'spec_helper'

describe RGen::Location::Map do

  class TestMap
    include RGen::Location::Map

    define_locations do
      loc1 address: 0x10, data: 0x1234
    end

    define_locations data: 0x5678 do
      loc2 address: 0x20, data: 0x1234
      loc3 address: 0x30
    end
  end

  class TestMap2
    include RGen::Location::Map

    constructor do |attrs, defaults|
      attrs[:address] = 0x1F
      default_constructor(attrs, defaults)
    end

    define_locations do
      loc1 address: 0x10, data: 0x1234
    end

    define_locations data: 0x5678 do

      constructor do |attrs, defaults|
        attrs[:address] = 0x2F
        default_constructor(attrs, defaults)
      end

      loc2 address: 0x20, data: 0x1234
      loc3 address: 0x30
    end
  end

  before :each do
    @map1 = TestMap.new
    @map2 = TestMap2.new
  end

  it "Locations can be defined" do
    @map1.loc1.data.should == 0x1234
    @map2.loc1.data.should == 0x1234
  end

  it "Defaults attributes can be applied to definitions" do
    @map1.loc2.data.should == 0x1234
    @map1.loc3.data.should == 0x5678
    @map2.loc2.data.should == 0x1234
    @map2.loc3.data.should == 0x5678
  end

  it "The default constructor can be overridden" do
    @map1.loc1.address.should == 0x10
    @map2.loc1.address.should == 0x1F
  end
  
  it "The default constructor can be overridden by a define block" do
    @map1.loc2.address.should == 0x20
    @map2.loc2.address.should == 0x2F
  end

end
