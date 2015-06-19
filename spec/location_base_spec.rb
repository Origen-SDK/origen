require 'spec_helper'

describe RGen::Location::Base do

  L = RGen::Location::Base

  it "the address defaults to byte address" do
    l = L.new(byte_address: 0x10)
    l.address.should == 0x10 
    l.byte_address.should == 0x10 
    l = L.new(address: 0x20)
    l.address.should == 0x20 
    l.byte_address.should == 0x20 
  end

  it "does word address manipulation" do
    l = L.new(address: 0x103)
    l.word_address.should == 0x81 
    l.word_aligned_address.should == 0x102
    l.word_aligned_byte_address.should == 0x102
  end

  it "word size can be overridden" do
    l = L.new(address: 0x103, word_size_in_bytes: 4)
    l.word_address.should == 0x40 
    l.word_aligned_address.should == 0x100
    l.word_aligned_byte_address.should == 0x100
  end

  it "does any other address manipulation" do
    l = L.new(address: 0x103, phrase_size_in_bytes: 8)
    l.phrase_address.should == 0x20 
    l.phrase_aligned_address.should == 0x100
    l.phrase_aligned_byte_address.should == 0x100
  end

  it "respond_to knows about the address manipulation methods" do
    l = L.new(address: 0x103, phrase_size_in_bytes: 8)
    l.respond_to?(:phrase_aligned_address).should == true
    l.respond_to?(:phrase_aligned_byte_address).should == true
  end

  it "is big endian by default" do
    l = L.new(address: 0x103)
    l.big_endian?.should == true
    l.endianess.should == :big
  end

  it "can be assigned a size in bytes, the default is 1" do
    L.new(address: 0x103).size_in_bytes.should == 1
    L.new(address: 0x103, size_in_bytes: 4).size_in_bytes.should == 4
  end

  it "data aligns as required if big endian and a size is supplied with the data" do
    l = L.new(address: 0x103, size_in_bytes: 4)
    l.write(0x1234)
    l.data.should == 0x1234
    l.write(0x1234, size_in_bytes: 2)
    l.data.should == 0x1234_0000
    l = L.new(address: 0x103, size_in_bytes: 4, endian: :little)
    l.write(0x1234)
    l.data.should == 0x1234
    l.write(0x1234, size_in_bytes: 2)
    l.data.should == 0x1234
  end

  it "data pads with 1's if specified" do
    l = L.new(address: 0x103, size_in_bytes: 4, nil_state: 1)
    l.write(0x1234)
    l.data.should == 0x1234
    l.write(0x1234, size_in_bytes: 2)
    l.data.should == 0x1234_FFFF
    l.data(nil_state: 0).should == 0x1234_0000
    l = L.new(address: 0x103, size_in_bytes: 4, endian: :little, nil_state: 1)
    l.write(0x1234)
    l.data.should == 0x1234
    l.write(0x1234, size_in_bytes: 2)
    l.data.should == 0xFFFF_1234
  end

end
