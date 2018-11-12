require "spec_helper"

# This module and double include below are required to give access to add_reg
# and similar methods from within the tests, but without adding the registers
# module to the global namespace which gives weird errors when the placeholder
# and other register objects pick up the top-level methods.
module RegTest

  include Origen::Registers

  describe Container do

    include Origen::Registers

    it "is 32 bits by default" do
      Container.new.size.should == 32
    end

    it "is big endian by default" do
      Container.new.big_endian?.should == true
      Container.new(endian: :little).big_endian?.should == false
    end

    it "contains bits" do
      Container.new.contains_bits?.should == true
    end

     it "updates it's address based on the address of the contained register(s)" do
      c = Container.new
      r1 = Reg.new(self, 0, 8, :r1, {})
      r2 = Reg.new(self, 1, 8, :r2, {})
      r3 = Reg.new(self, 2, 8, :r3, {})
      r4 = Reg.new(self, 3, 8, :r4, {})
      c.address.should == nil
      c.add(r1).address.should == 0
      c.empty
      c.address.should == nil
      c.add(r2).address.should == 0
      c.add(r3).address.should == 0
      c.add(r4).address.should == 0
      c.empty
      r5 = Reg.new(self, 6, 16, :r5, {})
      c.add(r5).address.should == 4
    end

    it "accepts an address override when adding registers" do
      c = Container.new
      r1 = Reg.new(self, 0, 8, :r1, {})
      r2 = Reg.new(self, 1, 8, :r2, {})
      r3 = Reg.new(self, 2, 8, :r3, {})
      r4 = Reg.new(self, 3, 8, :r4, {})
      c.address.should == nil
      c.add(r1, address: 4).address.should == 4
      c.empty
      c.address.should == nil
      c.add(r2, address: 5).address.should == 4
      c.add(r3, address: 6).address.should == 4
      c.add(r4, address: 7).address.should == 4
      c.empty
      r5 = Reg.new(self, 6, 16, :r5, {})
      c.add(r5, address: 10).address.should == 8
    end

    it "it's owner is the same as the register's" do
      c = Container.new
      owner = Container.new
      r1 = Reg.new(owner, 0, 16, :r1, {})
      c.owner.should == nil
      c.owned_by?('owner').should == false
      c.add(r1).owner.should == owner
      c.owned_by?('owner').should == false
      c.owned_by = 'cont_owner'
      c.owned_by?('cont_owner').should == true
    end

    it "keeps the registers in address order" do
      c = Container.new
      r1 = Reg.new(self, 0, 8, :r1, {})
      r2 = Reg.new(self, 1, 8, :r2, {})
      r3 = Reg.new(self, 2, 8, :r3, {})
      r4 = Reg.new(self, 3, 8, :r4, {})
      c.add(r3)
      c.add(r1)
      c.regs[0].should == r1
      c.add(r2)
      c.regs[0].should == r1
      c.regs[1].should == r2
      c.regs[2].should == r3
    end

    it "keeps the registers in address order with overrides" do
      c = Container.new
      r1 = Reg.new(self, 0, 8, :r1, {})
      r2 = Reg.new(self, 1, 8, :r2, {})
      r3 = Reg.new(self, 2, 8, :r3, {})
      r4 = Reg.new(self, 3, 8, :r4, {})
      c.add(r3)
      c.add(r1)
      c.regs[0].should == r1
      c.add(r4, address: 1)
      c.regs[0].should == r1
      c.regs[1].should == r4
      c.regs[2].should == r3
    end

    it "calculates the byte enable correctly" do
      big = Container.new
      little = Container.new(endian: :little)
      r1 = Reg.new(self, 0, 8, :r1, {})
      r2 = Reg.new(self, 1, 8, :r2, {})
      r3 = Reg.new(self, 2, 8, :r3, {})
      r4 = Reg.new(self, 3, 8, :r4, {})
      r5 = Reg.new(self, 2, 16, :r5, {})
      big.add(r1)
      little.add(r1)
      big.byte_enable.should    == 0b0001
      little.byte_enable.should == 0b1000
      big.add(r3)
      little.add(r3)
      big.byte_enable.should    == 0b0101
      little.byte_enable.should == 0b1010
      big.empty
      little.empty
      big.add(r5)
      little.add(r5)
      big.byte_enable.should    == 0b1100
      little.byte_enable.should == 0b0011
      big.add(r1)
      little.add(r1)
      big.byte_enable.should    == 0b1101
      little.byte_enable.should == 0b1011
    end

    it "calculates the data correctly" do
      big = Container.new
      little = Container.new(endian: :little)    
      r1 = Reg.new(self, 0, 8,  :r1, data: {bits: 8})
      r2 = Reg.new(self, 1, 8,  :r2, data: {bits: 8})
      r3 = Reg.new(self, 2, 16, :r3, data: {bits: 16})
      r1.write(0x11)
      r2.write(0x22)
      r3.write(0x3333)
      big.data.should == 0
      little.data.should == 0
      big.data_b.should == 0xFFFF_FFFF
      little.data_b.should == 0xFFFF_FFFF
      big.add(r1)
      little.add(r1)
      big.data.should == 0x0000_0011
      little.data.should == 0x1100_0000
      big.data_b.should == 0xFFFF_FFEE
      little.data_b.should == 0xEEFF_FFFF
      big.add(r2)
      little.add(r2)
      big.data.should == 0x0000_2211
      little.data.should == 0x1122_0000
      big.add(r3)
      little.add(r3)
      big.data.should == 0x3333_2211
      little.data.should == 0x1122_3333
    end

    it "works with a real life data example" do
      big = Container.new
      r1 = Reg.new(self, 26, 16,  :r1, data: {bits: 16})
      r1.write(0x7E00)
      big.add(r1, address: 4)
      big.data.should == 0x0000_7E00
      big.big_endian?.should == true
      big.little_endian?.should == false
      r1.read
      r1.is_to_be_read?.should == true
      big.clear_flags
      r1.is_to_be_read?.should == false
    end

    it "works with another real life data example" do
      little = Container.new(endian: :little)
      r1 = Reg.new(self, 26, 8,  :r1, data: {bits: 8})
      r1.write(0x80)
      little.add(r1, address: 3)
      little.data.should == 0x0000_0080
      little.little_endian?.should == true
      little.big_endian?.should == false
    end

    it "can be shifted left" do
      big = Container.new
      little = Container.new(endian: :little)
      r1 = Reg.new(self, 0, 8,  :r1, data: {bits: 8})
      r2 = Reg.new(self, 1, 8,  :r2, data: {bits: 8})
      r3 = Reg.new(self, 2, 16, :r3, data: {bits: 16})
      r1.write(0x11)
      r2.write(0x22)
      r3.write(0x3333)
      big.add(r1).add(r3)
      little.add(r1).add(r3)
      expected = [0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1]
      big.shift_out_left_with_index do |bit, i|
        bit.data.should == expected[i]
      end
      expected = [0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1]
      little.shift_out_left_with_index do |bit, i|
        bit.data.should == expected[i]
      end
    end

    it "can be shifted right" do
      big = Container.new
      little = Container.new(endian: :little)
      r1 = Reg.new(self, 0, 8,  :r1, data: {bits: 8})
      r2 = Reg.new(self, 1, 8,  :r2, data: {bits: 8})
      r3 = Reg.new(self, 2, 16, :r3, data: {bits: 16})
      r1.write(0x11)
      r2.write(0x22)
      r3.write(0x3333)
      big.add(r1).add(r3)
      little.add(r1).add(r3)
      expected = [1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0]
      big.shift_out_right_with_index do |bit, i|
        bit.data.should == expected[i]
      end
      expected = [1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1,0,0,0]
      little.shift_out_right_with_index do |bit, i|
        bit.data.should == expected[i]
      end
    end

    it "containers can incorporate other containers" do
      c1 = Container.new(size: 16)
      c2 = Container.new
      r1 = Reg.new(self, 0, 8,  :r1, data: {bits: 8})
      r2 = Reg.new(self, 1, 8,  :r2, data: {bits: 8})
      r3 = Reg.new(self, 2, 16, :r3, data: {bits: 16})
      r1.write(0x11)
      r2.write(0x22)
      r3.write(0x3333)
      c1.add(r1).add(r2)
      c2.add(c1).add(r3)
      c1.data.should == 0x0000_2211
      c2.data.should == 0x3333_2211
      c2.address.should == 0
      c2.byte_enable.should == 0b1111
      expected = [0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,0,0,0,1,0,0,0,0,1,0,0,0,1]
        puts ""
      c2.shift_out_left_with_index do |bit, i|
        bit.data.should == expected[i]
      end
      expected = [1,0,0,0,1,0,0,0,0,1,0,0,0,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0]
      c2.shift_out_right_with_index do |bit, i|
        bit.data.should == expected[i]
      end
    end

  end
end
