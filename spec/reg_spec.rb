require "spec_helper"

# This module and double include below are required to give access to add_reg
# and similar methods from within the tests, but without adding the registers
# module to the global namespace which gives weird errors when the placeholder
# and other register objects pick up the top-level methods.
module RegTest
  
  include Origen::Registers

  describe Reg do

    include Origen::Registers

    def read_register(reg, options={})
      # Dummy method to allow the bang methods to be tested
    end

    def write_register(reg, options={})
      # Dummy method to allow the bang methods to be tested
    end

   it "Reads in excel TCU registers by forward single bits in range" do
      reg :tcu, 0x0024, size: 8 do
        bits 7,   :peter,  reset: 0
        bits 6,   :mike,  reset: 0
        bits 5,   :mike,  reset: 0
        bits 4,   :mike,  reset: 0
        bits 3, :peter, reset: 1
        bits 2, :peter, reset: 1
        bits 1,   :pan,  reset: 0
        bits 0,   :peter,  reset: 0
      end
      
        reg(:tcu).data.should == 12
        reg(:tcu).bits(:peter).size.should == 4
        reg(:tcu).bits(:peter).data.should == 0b0110
        reg(:tcu).bits(:peter).write(0)
        reg(:tcu).data.should == 0
        reg(:tcu).bits(:peter).data.should == 0
        reg(:tcu).bits(:peter).write(7)
        reg(:tcu).data.should == 0b1101
        reg(:tcu).bits(:peter).data.should == 7
        reg(:tcu).reset
        reg(:tcu).data.should == 12
        reg(:tcu).contains_bits?.should == true
    end
=begin   
    it "Reads in excel TCU registers by backwards single bits in range" do
      reg :tcu3, 0x0024, size: 8 do
        
        bits 0,   :peter,  reset: 0
        bits 1,   :pan,  reset: 0
        bits 2, :peter[1], reset: 1
        bits 3, :peter[2], reset: 1
        bits 4,   :mike,  reset: 0
        bits 5,   :mike,  reset: 0
        bits 6,   :mike,  reset: 0
        bits 7,   :mike,  reset: 0
      end
        reg(:tcu3).data.should == 12
        reg(:tcu3).bits(:peter).size.should == 3
        reg(:tcu3).bits(:peter).data.should == 0b110
        reg(:tcu3).bits(:peter).write(0)
        reg(:tcu3).data.should == 0
        reg(:tcu3).bits(:peter).data.should == 0
        reg(:tcu3).bits(:peter).write(7)
        reg(:tcu3).data.should == 0b1101
        reg(:tcu3).bits(:peter).data.should == 7
        reg(:tcu3).reset
        reg(:tcu3).data.should == 12
    end
=end

    it "Reads in excel TCU registers forward description" do
      reg :tcu, 0x0024, size: 8 do
        bits 7,   :peter,  reset: 0
        bits 6..4,   :mike,  reset: 0
        bits 3..2, :peter, reset: 3
        bits 1,   :pan,  reset: 0
        bits 0,   :peter,  reset: 0
      end
        reg(:tcu).data.should == 12
        reg(:tcu).bits(:peter).size.should == 4
        reg(:tcu).bits(:peter).data.should == 0b0110
        reg(:tcu).bits(:peter).write(0)
        reg(:tcu).data.should == 0
        reg(:tcu).bits(:peter).data.should == 0
        reg(:tcu).bits(:peter).write(7)
        reg(:tcu).data.should == 0b1101
        reg(:tcu).bits(:peter).data.should == 7
        reg(:tcu).reset
        reg(:tcu).data.should == 12
    end
=begin    
    it "Reads in excel TCU registers backwards description" do
      reg :tcu2, 0x0024, size: 8 do
        bits 0,   :peter,  reset: 0
        bits 1,   :pan,  reset: 0
        bits 3..2, :peter, reset: 3
        bits 7..4,   :mike,  reset: 0
      end
        reg(:tcu2).data.should == 12
        reg(:tcu2).bits(:peter).size.should == 3
        reg(:tcu2).bits(:peter).data.should == 0b110
        reg(:tcu2).bits(:peter).write(0)
        reg(:tcu2).data.should == 0
        reg(:tcu2).bits(:peter).data.should == 0
        reg(:tcu2).bits(:peter).write(7)
        reg(:tcu2).data.should == 0b1101
        reg(:tcu2).bits(:peter).data.should == 7
        reg(:tcu2).reset
        reg(:tcu2).data.should == 12
    end
=end
    it "Reads in excel TCU registers in multiple ranges" do
      reg :tcu, 0x0070, size: 16 do
        bits 15,   :mike,  reset: 1
        bits 14,   :bill,  reset: 0
        bits 13,   :robert,  reset: 1
        bits 12,   :james,  reset: 0
        bits 11,   :james, reset: 1
        bits 10,   :james, reset: 0
        bits 9,    :paul,  reset: 1
        bits 8,    :peter,  reset: 0
        bits 7,    :mike,  reset: 1
        bits 6,    :mike,  reset: 0
        bits 5,    :paul,  reset: 1
        bits 4,    :paul,  reset: 0
        bits 3,    :mike, reset: 1
        bits 2,    :robert, reset: 0
        bits 1,    :bill,  reset: 0
        bits 0,    :ian,  reset: 1
      end
        reg(:tcu).data.should == 43689
        #check sizes
        reg(:tcu).bits(:bill).size.should == 2
        reg(:tcu).bits(:ian).size.should == 1
        reg(:tcu).bits(:james).size.should == 3
        reg(:tcu).bits(:mike).size.should == 4
        reg(:tcu).bits(:paul).size.should == 3
        reg(:tcu).bits(:peter).size.should == 1
        reg(:tcu).bits(:robert).size.should == 2
      #check reset data
        reg(:tcu).bits(:bill).data.should == 0
        reg(:tcu).bits(:ian).data.should == 1
        reg(:tcu).bits(:james).data.should == 2
        reg(:tcu).bits(:mike).data.should == 13
        reg(:tcu).bits(:paul).data.should == 6
        reg(:tcu).bits(:peter).data.should == 0
        reg(:tcu).bits(:robert).data.should == 2
        #write register to all 1
        
        reg(:tcu).write(0xFFFF)
        reg(:tcu).data.should == 65535
        
        #write :peter to 0 and james[1] to 0
        reg(:tcu).bits(:peter).write(0b0)
        reg(:tcu).bits(:james)[1].write(0b0)
        reg(:tcu).bits(:peter).data.should == 0
        reg(:tcu).bits(:james).data.should == (0b101)
        reg(:tcu).data.should == 63231
        
        
  
        #write mike to 1010 and james[2] to 1
        reg(:tcu).bits(:mike).write(0b1010)
        reg(:tcu).bits(:james)[2].write(0)
        reg(:tcu).bits(:mike).data.should == 10
        reg(:tcu).bits(:james).data.should == (0b001)
        reg(:tcu).data.should == 58999
      
        reg(:tcu).reset
        reg(:tcu).data.should == 43689
      
    end




    it "can be initialized" do
        Reg.new(self, 0, 16, :dummy, bit0: {pos: 0}, 
                                     bit1: {pos: 1}, 
                                     bus0: {pos: 2, bits: 4}).is_a?(Reg).should == true
    end

    it "has an address" do
        Reg.new(self, 0x10, 16, :dummy).address.should == 0x10
    end


    it "has a reset data value" do
        reg = Reg.new(self, 0x10, 16, :dummy)
        reg.data.should == 0
        Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, res: 1}, 
                                        b1: {pos: 1, res: 1}).data.should == 0x3
        Reg.new(self, 0x10, 17, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                        b1: {pos: 8, bits: 8, res: 0xAA},
                                        b2: {pos: 16, res: 1}).data.should == 0x1AA55
    end

    it "stores reset data at bit level" do       
        reg = Reg.new(self, 0x10, 17, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 8, res: 0xAA},
                                              b2: {pos: 16, res: 1})      
        reg.bit(:b0).data.should == 0x55
        reg.bit(:b1).data.should == 0xAA
        reg.bit(:b2).data.should == 1
    end

    specify "bits can be accessed via reg.bit(:name) or reg.bits(:name)" do
        reg = Reg.new(self, 0x10, 17, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 8, res: 0xAA},
                                              b2: {pos: 16, res: 1})
        reg.bits(:b0).data.should == 0x55
        reg.bits(:b1).data.should == 0xAA
        reg.bits(:b2).data.should == 1
    end

    specify "bits can be accessed via position number" do
        reg = Reg.new(self, 0x10, 17, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 8, res: 0x0},
                                              b2: {pos: 16, res: 0})
        reg.bit(0).data.should == 1
        reg.bit(1).data.should == 0
        reg.bit(2).data.should == 1
    end

    specify "bits can be written directly" do
        reg = Reg.new(self, 0x10, 17, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 8, res: 0xAA},
                                              b2: {pos: 16, res: 1})

        reg.bits(:b1).data.should == 0xAA
        reg.bits(:b1).write(0x13)
        reg.bits(:b1).data.should == 0x13
        reg.bits(:b2).data.should == 1
    end

    specify "bits can be written indirectly" do
        reg = Reg.new(self, 0x10, 17, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 8, res: 0xAA},
                                              b2: {pos: 16, res: 1})

        reg.write(0x1234)
        reg.bits(:b0).data.should == 0x34
        reg.bits(:b1).data.should == 0x12
        reg.bits(:b2).data.should == 0
    end

    specify "only defined bits capture state" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 4, res: 0x55}, 
                                              b1: {pos: 8, bits: 4, res: 0xAA})
        reg.write(0xFFFF) 
        reg.data.should == 0x0F0F
    end

    specify "bits can be reset indirectly" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 8, res: 0xAA})
        reg.write(0xFFFF) 
        reg.data.should == 0xFFFF
        reg.reset
        reg.data.should == 0xAA55
    end

    specify "data can be readback bitwise" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 8, res: 0xAA})
        reg.data[0].should == 1
        reg.data[1].should == 0
        reg.data[2].should == 1
    end

    it "has a size attribute to track the number of bits" do
        Reg.new(self, 0x10, 16, :dummy).size.should == 16
        Reg.new(self, 0x10, 36, :dummy).size.should == 36
    end

    it "can shift out left" do
        reg = Reg.new(self, 0x10, 8, :dummy, b0: {pos: 0, bits: 4, res: 0x5}, 
                                             b1: {pos: 4, bits: 4, res: 0xA})
        expected = [1,0,1,0,0,1,0,1]
        x = 0
        reg.shift_out_left do |bit|
          bit.data.should == expected[x]
          x += 1
        end
        reg.write(0xF0)
        expected = [1,1,1,1,0,0,0,0]
        x = 0
        reg.shift_out_left do |bit|
          bit.data.should == expected[x]
          x += 1
        end
    end

    it "can shift out right" do
        reg = Reg.new(self, 0x10, 8, :dummy, b0: {pos: 0, bits: 4, res: 0x5}, 
                                             b1: {pos: 4, bits: 4, res: 0xA})
        expected = [1,0,1,0,0,1,0,1]
        x = 0
        reg.shift_out_right do |bit|
          bit.data.should == expected[7-x]
          x += 1
        end
        reg.write(0xF0)
        expected = [1,1,1,1,0,0,0,0]
        x = 0
        reg.shift_out_right do |bit|
          bit.data.should == expected[7-x]
          x += 1
        end
    end

    it "can shift out with holes present" do
        reg = Reg.new(self, 0x10, 8, :dummy, b0: {pos: 1, bits: 2, res: 0b11}, 
                                             b1: {pos: 6, bits: 1, res: 0b1})
        
        expected = [0,1,0,0,0,1,1,0]
        x = 0
        reg.shift_out_left do |bit|
          bit.data.should == expected[x] 
          x += 1
        end
        expected = [0,1,1,0,0,0,1,0]
        x = 0
        reg.shift_out_right do |bit|
          bit.data.should == expected[x] 
          x += 1
        end
    end

    specify "read method tags all bits for read" do
        reg = Reg.new(self, 0x10, 16, :dummy)
        reg.read
        16.times do |n|
            reg.bit(n).is_to_be_read?.should == true
        end
    end

    # This test added due to problems shifting out buses
    it "can shift out left with holes and buses" do
        reg = Reg.new(self, 0x10, 8, :dummy, b0: {pos: 5}, 
                                             b1: {pos: 0, bits: 4})
        reg.write(0xFF)
        reg.data.should == 0b00101111
        expected = [0,0,1,0,1,1,1,1]
        x = 0
        reg.shift_out_left do |bit|
          bit.data.should == expected[x]
          x += 1
        end
    end

    specify "bits mark as update required correctly" do
        reg = Reg.new(self, 0x10, 8, :dummy, b0: {pos: 5, res: 1}, 
                                             b1: {pos: 0, bits: 4, res: 3})

        reg.update_required?.should == false
        reg.write(0x23)
        reg.update_required?.should == false
        reg.write(0x0F)
        reg.update_required?.should == true
    end

    specify "clear_flags clears update required" do
        reg = Reg.new(self, 0x10, 8, :dummy, b0: {pos: 5, res: 1}, 
                                             b1: {pos: 0, bits: 4, res: 3})

        reg.write(0x0F)
        reg.update_required?.should == true
        reg.clear_flags
        reg.update_required?.should == false
    end


    specify "can index through named bits" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 4, res: 0xA},
                                              b2: {pos: 14,bits: 2, res: 1})      
        reg.named_bits do |name, bits|
            case name
            when :b0
                bits.write(0x1)
            when :b1             
                bits.write(0x2)
            when :b2
                bits.write(0x3)
            end
        end
        reg.data.should == 0xC201
        reg.bits(:b1).data.should == 0x2
    end

    specify "can use named bits with bit ordering" do
        reg1 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 1, bits: 7, res: 0x55}, 
                                               b1: {pos: 8, bits: 4, res: 0xA},
                                               b2: {pos: 14,bits: 2, res: 1})

        reg2 = Reg.new(self, 0x11, 8, :dummy_msb, bit_order: :msb0, msb0: {pos: 6, bits: 1}, 
                                                                    msb1: {pos: 4, bits: 2, res: 0x3},
                                                                    msb2: {pos: 0, bits: 1, res: 1})
  
        reg1.named_bits[0] == reg1.bits(:b0) 
        reg1.named_bits[2] == reg1.bits(:b2) 
        reg1.named_bits(include_spacers: true)[1] == reg1.bits(:b0) 
        reg1.named_bits(include_spacers: true)[4] == reg1.bits(:b2) 
        reg2.named_bits[0] == reg2.bits(:msb0) 
        reg2.named_bits[2] == reg2.bits(:msb2) 
        reg2.named_bits(include_spacers: true)[1] == reg2.bits(:msb0) 
        reg2.named_bits(include_spacers: true)[4] == reg2.bits(:msb2) 
        names = []
        reg1.named_bits { |name, bits| names.push(name) }
        names.should == [:b2, :b1, :b0]
        names = []
        reg1.named_bits(include_spacers: true) { |name, bits| names.push(name) }
        names.should == [:b2, nil, :b1, :b0, nil]
        names = []
        reg2.named_bits { |name, bits| names.push(name) }
        names.should == [:msb2, :msb1, :msb0]
        names = []
        reg2.named_bits(include_spacers: true) { |name, bits| names.push(name) }
        names.should == [:msb2, nil, :msb1, :msb0, nil]
         #reg1.reverse_named_bits[2] == reg1.bits(:b2) 
    end

    specify "can check bit positions of used_bits" do
        reg1 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 4, res: 0xA},
                                              b2: {pos: 14,bits: 2, res: 1})

        reg2 = Reg.new(self, 0x11, 8, :dummy_fstat, fstat0: {pos: 7, bits: 1}, 
                                              fstat1: {pos: 4, bits: 2, res: 0x3},
                                              fstat2: {pos: 0,bits: 1, res: 1})
                                              
        reg1.used_bits.should == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 14, 15]
        reg2.used_bits.should == [0, 4, 5, 7]
    end

    specify "can check for presence used_bits" do
        reg1 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 4, res: 0xA},
                                              b2: {pos: 14,bits: 2, res: 1})

        reg2 = Reg.new(self, 0x11, 8, :dummy_fstat, fstat0: {pos: 7, bits: 1}, 
                                              fstat1: {pos: 4, bits: 2, res: 0x3},
                                              fstat2: {pos: 0,bits: 1, res: 1})
                                              
        reg3 = Reg.new(self, 0x12, 32, :dummy_empty)
        
        reg1.used_bits?.should == true
        reg2.used_bits?.should == true
        reg3.used_bits?.should == false
    end

    specify "can check bit positions of empty_bits" do
        reg1 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 4, res: 0xA},
                                              b2: {pos: 14,bits: 2, res: 1})

        reg2 = Reg.new(self, 0x11, 8, :dummy_fstat, fstat0: {pos: 7, bits: 1}, 
                                              fstat1: {pos: 4, bits: 2, res: 0x3},
                                              fstat2: {pos: 0,bits: 1, res: 1})
                                              
        reg1.empty_bits.should == [12, 13]
        reg2.empty_bits.should == [1, 2, 3, 6]
    end

    specify "can check for presence empty_bits" do
        reg1 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 4, res: 0xA},
                                              b2: {pos: 12, bits: 1},
                                              b3: {pos: 13, bits: 1},
                                              b4: {pos: 14,bits: 2, res: 1})

        reg2 = Reg.new(self, 0x11, 8, :dummy_fstat, fstat0: {pos: 7, bits: 1}, 
                                              fstat1: {pos: 4, bits: 2, res: 0x3},
                                              fstat2: {pos: 0,bits: 1, res: 1})
                                              
        reg3 = Reg.new(self, 0x12, 32, :dummy_empty)
        reg4 = Reg.new(self, 0x13, 32, :dummy_empty, full32: {pos: 0, bits: 32})
        reg5 = Reg.new(self, 0x14, 8, :dummy_empty, full8: {pos: 0, bits: 8})
        
        reg1.empty_bits?.should == false
        reg2.empty_bits?.should == true
        reg3.empty_bits?.should == true
        reg4.empty_bits?.should == false
        reg5.empty_bits?.should == false
        
    end
    
    specify "can set bitw1c attribute and query w1c status" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 4, res: 0xA},
                                              b2: {pos: 12, bits: 1, w1c: true},
                                              b3: {pos: 13, bits: 1, w1c: false},
                                              b4: {pos: 14,bits: 1, res: 1})

        reg.bit(:b2).w1c.should == true
        reg.bit(:b3).w1c.should == false
        reg.bit(:b4).w1c.should == false
    end

    it "should not flatten" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 4, res: 0xA},
                                              b2: {pos: 14,bits: 2, res: 1})
        [reg].flatten.size.should == 1
        [reg].flatten.first.should == reg
    end


    it "should respond to bit collection methods" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8, res: 0x55}, 
                                              b1: {pos: 8, bits: 4, res: 0xA},
                                              b2: {pos: 14,bits: 2, res: 1})
        reg.respond_to?("data").should == true
        reg.respond_to?("read").should == true
        reg.respond_to?("some_nonsens").should_not == true
    end

    it "can create a dummy Reg for use on the fly" do
        Reg.dummy.size.should == 16
    end

    it "dummy regs can shift" do
      i = 0
      Reg.dummy.shift_out_right do |bit|
        bit.position.should == i
        i += 1
      end
    end

    it "should respond to value as an alias of data" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                              b1: {pos: 8, bits: 8})
        reg.write(0x1234)
        reg.data.should == 0x1234
        reg.value.should == 0x1234
    end

    specify "when data= is passed a Reg object the reg#data value is used" do
        reg1 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                               b1: {pos: 8, bits: 8})
        reg2 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                               b1: {pos: 8, bits: 8})
        reg1.data = 0x5678
        reg2.data = reg1
        reg2.data.should == 0x5678
    end

    specify "bits can be deleted" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                              b1: {pos: 8, bits: 8})
        reg.has_bit?(:b1).should == true
        reg.bits(:b1).delete
        reg.has_bit?(:b1).should == false
        reg.write(0xFFFF)
        reg.data.should == 0x00FF
    end

    specify "clone works correctly" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                              b1: {pos: 8, bits: 8})
        reg2 = reg.clone
        reg.write(0x1234)
        reg2.data.should_not == 0x1234
        reg.bits(:b1).delete
        reg.has_bits(:b1).should == false
        reg2.has_bits(:b1).should == true
    end

    specify "a reg object in a hash merge works correctly" do
        reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                              b1: {pos: 8, bits: 8})
        overrides = {}
        options = {reg: reg}.merge(overrides)
        options[:reg].should == reg
        overrides[:reg] = 2
        options = {reg: reg}.merge(overrides)
        options[:reg].should == 2
    end

    it "can be copied" do
        reg1 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                               b1: {pos: 8, bits: 8})
        reg2 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                               b1: {pos: 8, bits: 8})
        reg1.overlay("hello")
        reg1.write(0x1234)
        reg2.copy(reg1)
        reg1.overlay_str.should == "hello"
        reg1.data.should == 0x1234
    end

    specify "copy works via the reg API" do
      load_target
      reg1 = $nvm.reg(:mclkdiv)
      reg2 = $nvm.reg(:data)
      reg1.overlay("hello")
      reg1.write(0x1234)
      reg2.copy(reg1)
      reg1.overlay_str.should == "hello"
      reg1.data.should == 0x1234
    end

    specify "copy works with bit collections" do
      load_target
      reg1 = $nvm.reg(:mclkdiv)
      reg1 = reg1.bits
      reg2 = $nvm.reg(:data)
      reg1.overlay("hello")
      reg1.write(0x1234)
      reg2.copy(reg1)
      reg1.overlay_str.should == "hello"
      reg1.data.should == 0x1234
    end

    specify "bit collections can be copied to other bitcollections" do
      cpreg1 = Reg.new(self, 0x110, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                                b1: {pos: 8, bits: 8})
      cpreg2 = Reg.new(self, 0x111, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                                b1: {pos: 8, bits: 8})
      bits1 = cpreg1.b0
      bits2 = cpreg2.b0
      bits1.data.should == 0
      bits1[1].is_to_be_read?.should == false
      bits2.read(0b0010)
      bits1.copy_all(bits2)
      bits1.data.should == 0b0010
      bits1[1].is_to_be_read?.should == true
      bits1.is_to_be_read?.should == true

      # Bit collection copy can also accept a flat value, in which case
      # it is just a write that clears flags:

      bits1.copy_all(0b1001)
      bits1.data.should == 0b1001
      bits1[1].is_to_be_read?.should == false
      bits1.is_to_be_read?.should == false
    end

    specify "status string methods work" do
      reg = Reg.new(self, 0x112, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                             b1: {pos: 8, bits: 8})
      reg[3..0].write(0x5)
      reg[7..4].overlay("overlayx")
      reg[15..8].write(0xAA)
      reg[10].overlay("overlayy")
      reg.status_str(:write).should == "A(1v10)V5"
      reg.reset
      reg.clear_flags
      reg.overlay(nil)
      reg.status_str(:write).should == "0000"
      reg.status_str(:read).should == "XXXX"
      reg[7..4].read(5)
      reg.status_str(:read).should == "XX5X"
      reg[7..4].read(5)
      reg[14].read(0)
      reg.status_str(:read).should == "(x0xx)X5X"
      reg[3..0].store
      reg.status_str(:read).should == "(x0xx)X5S"
      reg[12..8].overlay("overlayx")
      reg[12..8].read
      reg.status_str(:read).should == "(x0xv)V5S"
      reg[15].store
      reg.status_str(:read).should == "(s0xv)V5S"
    end

    specify "the enable_mask method works" do
      reg = Reg.new(self, 0x113, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                             b1: {pos: 8, bits: 8})
      reg.enable_mask(:read).should == 0
      reg[7..4].read(0xA)
      reg.enable_mask(:read).should == 0xF0
    end

    specify "regs are correctly marked for read" do
      reg1 = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                             b1: {pos: 8, bits: 8})
      reg2 = Reg.new(self, 0x11, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                             b1: {pos: 8, bits: 8})
      reg3 = Reg.new(self, 0x12, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                             b1: {pos: 8, bits: 8})
      reg4 = Reg.new(self, 0x13, 16, :dummy, b0: {pos: 0, bits: 8}, 
                                             b1: {pos: 8, bits: 8})
      reg1.read
      reg1.is_to_be_read?.should == true
      reg2.read!
      reg2.is_to_be_read?.should == true
      reg3.read(0xFFFF)
      reg3.is_to_be_read?.should == true
      reg4.read!(0xFFFF)
      reg4.is_to_be_read?.should == true
    end

    specify "add_reg should not delete bits from the supplied bit hash" do
      bits = {
        b0: {pos: 0, bits: 8, writable: false},
        b1: {pos: 8, bits: 8, res: 4},
      }
      bits_copy = {
        b0: {pos: 0, bits: 8, writable: false},
        b1: {pos: 8, bits: 8, res: 4},
      }
      add_reg :dummy, 0x10, 16, bits
      bits.should == bits_copy
    end

    specify "reg(:blah) can be used to test for the presence of a register" do
      load_target
      $nvm.reg(:blah).should_not be
    end

    specify "reg(:blah) can be used to test for the presence of a register - not when strict" do
      Origen.config.strict_errors = true
      load_target
      puts "******************** Missing register error expected here ********************"
      lambda do
        $nvm.reg(:blah).should_not be
      end.should raise_error
    end

    it "registers can be overridden in sub classes" do
      Origen.config.strict_errors = false
      Origen.app.unload_target!
      nvm = C99::NVMSub.new
      nvm.reg(:data).address.should == 0x4
      nvm.redefine_data_reg
      nvm.reg(:data).address.should == 0x40
    end

    it "registers can be overridden in sub classes - not when strict" do
      Origen.config.strict_errors = true
      Origen.app.unload_target!
      nvm = C99::NVMSub.new
      nvm.reg(:data).address.should == 0x4
      puts "******************** Redefine register error expected here ********************"
      lambda do
        nvm.redefine_data_reg
      end.should raise_error
    end

    specify "clone and dup mean clone the register, not the placeholder" do
      load_target
      $nvm.reg(:mclkdiv).class.should == Origen::Registers::Placeholder
      $nvm.reg(:data).class.should == Origen::Registers::Placeholder
      $nvm.reg(:mclkdiv).clone.class.should == Origen::Registers::Reg
      $nvm.reg(:data).dup.class.should == Origen::Registers::Reg
    end

    it "register owned_by method works" do
      $nvm.reg(:mclkdiv).owned_by?(:ram).should == false
      $nvm.reg(:mclkdiv).owned_by?(:nvm).should == true
      $nvm.reg(:mclkdiv).owned_by?(:flash).should == true
      $nvm.reg(:mclkdiv).owned_by?(:fmu).should == true
    end

    it "registers automatically pick up a base address from the object doing the read/write" do
      $nvm.reg(:mclkdiv).address.should == 0x4000_0003
    end

    it "registers pick up a base address from the object doing the write" do
      $nvm.reg(:mclkdiv).address(relative: true).should == 0x3
      $nvm.reg(:mclkdiv).write!
      $nvm.reg(:mclkdiv).address.should == 0x4000_0003
    end

    it "registers pick up a base address from the object doing the read" do
      $nvm.reg(:mclkdiv).address(relative: true).should == 0x3
      $nvm.reg(:mclkdiv).read!
      $nvm.reg(:mclkdiv).address.should == 0x4000_0003
    end

    it "registers can be declared in block format with descriptions" do
      Origen.app.unload_target!
      nvm = C99::NVMSub.new
      nvm.add_reg_with_block_format
      nvm.reg(:dreg).data.should == 0x8055
      nvm.reg(:dreg2).data.should == 0x8055
      nvm.reg(:dreg).write(0xFFFF)
      nvm.reg(:dreg).data.should == 0xFF55
      nvm.reg(:dreg).description(include_name: false).size.should == 1
      nvm.reg(:dreg).description(include_name: false).first.should == "This is dreg"
      nvm.reg(:dreg2).description(include_name: false).first.should == "This is dreg2"
      nvm.reg(:dreg).bit(:bit15).description.size.should == 1
      nvm.reg(:dreg).bit(:bit15).description.first.should == "This is dreg bit 15"
      nvm.reg(:dreg2).bit(:bit15).description.first.should == "This is dreg2 bit 15"
      nvm.reg(:dreg).bit(:lower).description.size.should == 2
      nvm.reg(:dreg).bit(:lower).description.first.should == "This is dreg bit lower"
      nvm.reg(:dreg2).bit(:lower).description.first.should == "This is dreg2 bit lower"
      nvm.reg(:dreg).bit(:lower).description.last.should == "This is dreg bit lower line 2"
      nvm.reg(:dreg2).bit(:lower).description.last.should == "This is dreg2 bit lower line 2"
    end

    it "register descriptions can be supplied via the API" do     
      Origen.app.unload_target!
      nvm = C99::NVMSub.new
      nvm.add_reg_with_block_format
      nvm.reg(:dreg3).description(include_name: false).size.should == 1
      nvm.reg(:dreg3).description(include_name: false).first.should == "This is dreg3"
      nvm.reg(:dreg3).bit(:bit15).description.size.should == 1
      nvm.reg(:dreg3).bit(:bit15).description.first.should == "This is dreg3 bit 15"
      nvm.reg(:dreg3).bit(:lower).description.size.should == 2
      nvm.reg(:dreg3).bit(:lower).description.first.should == "This is dreg3 bit lower"
      nvm.reg(:dreg3).bit(:lower).description.last.should == "This is dreg3 bit lower line 2"
    end

    it "bit value descriptions work" do
      Origen.app.unload_target!
      nvm = C99::NVMSub.new
      nvm.add_reg_with_block_format
      nvm.reg(:dreg).bits(:bit15).bit_value_descriptions.size.should == 0
      nvm.reg(:dreg).bits(:bit14).bit_value_descriptions.size.should == 2
      nvm.reg(:dreg3).bits(:bit15).bit_value_descriptions.size.should == 0
      nvm.reg(:dreg3).bits(:bit14).bit_value_descriptions.size.should == 2
      nvm.reg(:dreg4).bits(:busy).bit_value_descriptions.size.should == 19
      nvm.reg(:dreg4).bits(:busy).bit_value_descriptions(format: :hex).size.should == 19
      nvm.reg(:dreg4).bits(:busy).bit_value_descriptions(format: :dec).size.should == 19
      nvm.reg(:dreg).bits(:bit14).bit_value_descriptions[0].should == "Coolness is disabled"
      nvm.reg(:dreg).bits(:bit14).bit_value_descriptions[1].should == "Coolness is enabled"
      nvm.reg(:dreg3).bits(:bit14).bit_value_descriptions[0].should == "Coolness is disabled"
      nvm.reg(:dreg3).bits(:bit14).bit_value_descriptions[1].should == "Coolness is enabled"
      nvm.reg(:dreg4).bits(:busy).bit_value_descriptions[8].should == "Job8"
      nvm.reg(:dreg4).bits(:busy).bit_value_descriptions(format: :dec)[1000].should == "Job8"
      nvm.reg(:dreg4).bits(:busy).bit_value_descriptions(format: :hex)[4096].should == "Job8"
      lambda { nvm.reg(:dreg4).bits(:busy).bit_value_descriptions(format: :octal) }.should raise_error
      nvm.reg(:dreg).bits(:bit14).description(include_bit_values: false, include_name: false).should == ["This does something cool"]
      nvm.reg(:dreg3).bits(:bit14).description(include_bit_values: false, include_name: false).should == ["This does something cool"]
    end

    it "bit names from a description work" do
      Origen.app.unload_target!
      nvm = C99::NVMSub.new
      nvm.add_reg_with_block_format
      nvm.reg(:dreg).bits(:bit14).full_name.should == "Bit 14"
      nvm.reg(:dreg3).bits(:bit14).full_name.should == "Bit 14"
    end

    it "register names from a description work" do
      Origen.app.unload_target!
      nvm = C99::NVMSub.new
      nvm.add_reg_with_block_format
      nvm.reg(:dreg).full_name.should == "Data Register 3"
      nvm.reg(:dreg3).full_name.should == "Data Register 3"
    end

    it "supports defining a bit collection from a range" do
      reg :test, 10, size: 16 do
        bits 15..0, :data
      end
      reg :test_with_hole, 10, size: 16 do
        bits 15..12, :d1
        bits 7..0,   :d2
      end
      reg(:test).data.should == 0x0000
      reg(:test).bits(15..8).write(0x55)
      reg(:test).data.should == 0x5500
      reg(:test).bits(7..0).write(0xAA)
      reg(:test).data.should == 0x55AA
      reg(:test_with_hole).data.should == 0x0000
      reg(:test_with_hole).bits(15..8).write(0x55)
      reg(:test_with_hole).data.should == 0x5000
      reg(:test_with_hole).bits(7..0).write(0xAA)
      reg(:test_with_hole).data.should == 0x50AA
    end

    it "arbitrary meta data can be defined and read from registers and bits" do
      default_reg_metadata do |reg|
        reg.readable_in_user_mode = true
        reg.something_else = 20
        reg.blah = :blah
      end

      default_bit_metadata do |bit|
        bit.property_x = :x
        bit.property_y = :y
        bit.property_z = :z
      end

      reg :test1, 0, size: 16 do
        bit 15,   :bx
        bit 7..0, :by
      end

      reg :test2, 10, size: 16, readable_in_user_mode: false, something_else: 10 do
        bit 15,   :bx, property_x: "X"
        bit 7..0, :by, property_y: "Y", property_z: "Z"
      end

      reg(:test1).respond_to?(:readable_in_user_mode).should == true
      reg(:test1).respond_to?(:readable_in_user_mode?).should == true
      reg(:test1).respond_to?(:readable_in_test_mode).should == false
      reg(:test1).respond_to?(:something_else).should == true
      reg(:test1).respond_to?(:something_else?).should == false
      reg(:test1).respond_to?(:something_undefined).should == false
      reg(:test1).bit(:bx).respond_to?(:property_w).should == false
      reg(:test1).bit(:bx).respond_to?(:property_x).should == true
      reg(:test1).bit(:bx).respond_to?(:property_y).should == true
      reg(:test1).bit(:bx).respond_to?(:property_z).should == true
      reg(:test2).bit(:bx).respond_to?(:property_w).should == false
      reg(:test2).bit(:bx).respond_to?(:property_x).should == true
      reg(:test2).bit(:bx).respond_to?(:property_y).should == true
      reg(:test2).bit(:bx).respond_to?(:property_z).should == true
      reg(:test1).bit(:by).respond_to?(:property_w).should == false
      reg(:test1).bit(:by).respond_to?(:property_x).should == true
      reg(:test1).bit(:by).respond_to?(:property_y).should == true
      reg(:test1).bit(:by).respond_to?(:property_z).should == true
      reg(:test2).bit(:by).respond_to?(:property_w).should == false
      reg(:test2).bit(:by).respond_to?(:property_x).should == true
      reg(:test2).bit(:by).respond_to?(:property_y).should == true
      reg(:test2).bit(:by).respond_to?(:property_z).should == true

      reg(:test1).meta.should == {readable_in_user_mode: true, something_else: 20, blah: :blah}
      reg(:test2).meta.should == {readable_in_user_mode: false, something_else: 10, blah: :blah}
      reg(:test1).readable_in_user_mode.should == true
      reg(:test1).readable_in_user_mode?.should == true
      reg(:test2).readable_in_user_mode.should == false
      reg(:test2).readable_in_user_mode?.should == false
      reg(:test1).something_else.should == 20
      reg(:test2).something_else.should == 10

      reg(:test1).bit(:bx).meta.should == {property_x: :x, property_y: :y, property_z: :z}
      reg(:test2).bit(:bx).meta.should == {property_x: "X", property_y: :y, property_z: :z}
      reg(:test1).bit(:bx).property_x.should == :x
      reg(:test2).bit(:bx).property_x.should == "X"

      reg(:test1).bit(2).meta.should == {property_x: :x, property_y: :y, property_z: :z}
      reg(:test2).bit(2).meta.should == {property_x: :x, property_y: "Y", property_z: "Z"}
      reg(:test1).bit(2).property_x.should == :x
      reg(:test2).bit(2).property_x.should == :x
      reg(:test1).bit(2).property_y.should == :y
      reg(:test2).bit(2).property_y.should == "Y"

      reg(:test1).bits(:by).meta.should == {property_x: :x, property_y: :y, property_z: :z}
      reg(:test2).bits(:by).meta.should == {property_x: :x, property_y: "Y", property_z: "Z"}
      reg(:test1).bits(:by).property_x.should == :x
      reg(:test2).bits(:by).property_x.should == :x
      reg(:test1).bits(:by).property_y.should == :y
      reg(:test2).bits(:by).property_y.should == "Y"
    end

    it "arbitrary meta data is isolated to registers owned by a given class" do
      class MetaClass1
        include Origen::Registers
        def initialize
          default_reg_metadata do |reg|
            reg.property1 = 1
            reg.property2 = 2
          end

          reg :reg1, 0 do
            bit 31..0, :data
          end 
        end
      end

      class MetaClass2
        include Origen::Registers
        def initialize
          default_reg_metadata do |reg|
            reg.property1 = 3
          end

          reg :reg1, 0 do
            bit 31..0, :data
          end 
        end
      end

      reg1 = MetaClass1.new.reg(:reg1)
      reg2 = MetaClass2.new.reg(:reg1)
      reg1.property1.should == 1
      reg2.property1.should == 3
      reg1.respond_to?(:property2).should == true
      reg2.respond_to?(:property2).should == false
    end

    it "large bit collections work" do
      reg :regx, 0 do
        bit 31..0, :data
      end 
      reg = reg(:regx)
      reg.write(0x4C)
      reg.data.should == 0x4C
      lower = reg.bits(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15)
      lower.data.should == 0x4C
      lower = reg.bits(15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0)
      lower.data.should == 0x4C
    end

    it "global reg and bit meta data can be added by a plugin" do
      Origen::Registers.default_reg_meta_data do |reg|
        reg.attr_x
        reg.attr_y = 10
        reg.attr_z = 20
      end

      Origen::Registers.default_bit_meta_data do |bit|
        bit.attr_bx
        bit.attr_by = 10
        bit.attr_bz = 20
      end

      reg :regblah, 0, attr_z: 30 do
        bit 31..16, :upper, attr_bz: 5
        bit 15..1, :lower
        bit 0, :bit0, attr_by: 15
      end 

      reg(:regblah).attr_y.should == 10
      reg(:regblah).attr_z.should == 30
      reg(:regblah).attr_x.should == nil
      reg(:regblah).attr_x = :yo
      reg(:regblah).attr_x.should == :yo
      reg(:regblah).bits(:upper).attr_by.should == 10
      reg(:regblah).bits(:upper).attr_bz.should == 5
      reg(:regblah).bits(:upper).attr_bx.should == nil
      reg(:regblah).bits(:upper).attr_bx = :yo
      reg(:regblah).bits(:upper).attr_bx.should == :yo
      reg(:regblah).bit(:bit0).attr_by.should == 15
      reg(:regblah).bit(:bit0).attr_bz.should == 20
      reg(:regblah).bit(:bit0).attr_bx.should == nil
      reg(:regblah).bit(:bit0).attr_bx = :yo
      reg(:regblah).bit(:bit0).attr_bx.should == :yo
    end

    it "reg and bit reset data can be fetched" do
      reg :reset_test, 100 do
        bit 31..16, :upper, reset: 0x5555
        bit 15..1, :lower
        bit 0, :bit0, reset: 1
      end 

      reg(:reset_test).reset_val.should == 0x55550001
      reg(:reset_test).bits(:upper).reset_val.should == 0x5555
      reg(:reset_test).bits(:lower).reset_val.should == 0x0000
      reg(:reset_test).bit(:bit0).reset_val.should == 0x1 
      reg(:reset_test).write(0xFFFF_FFFF)
      reg(:reset_test).reset_val.should == 0x55550001
      reg(:reset_test).val.should == 0xFFFF_FFFF
    end

    it "reset values work correct in real life case" do
      reg :proth, 0x0024, size: 32 do
        bits 31..24,   :fprot7,  reset: 0xFF
        bits 23..16,   :fprot6,  reset: 0xEE
        bits 15..8,    :fprot5,  reset: 0xDD
        bits 7..0,     :fprot4,  reset: 0x11
      end
      reg(:proth).data.should == 0xFFEE_DD11
      reg(:proth).reset_val.should == 0xFFEE_DD11
      reg(:proth).bits(:fprot7).reset_val.should == 0xFF
      reg(:proth).bits(:fprot6).reset_val.should == 0xEE
      reg(:proth).bits(:fprot5).reset_val.should == 0xDD
      reg(:proth).bits(:fprot4).reset_val.should == 0x11
    end

    it "a few different bit names can be tried" do
      reg :multi_name, 0x0030 do
        bit 3, :some_bit3
        bit 2, :some_bit2
        bit 1, :some_bit1
        bit 0, :some_bit0
      end
      reg(:multi_name).bits(:blah1, :blah_blah1, :some_bit1).write(1)
      reg(:multi_name).data.should == 2
      # X chosen here specifically in the name so that when sorted it comes
      # after the name that will match a bit in this register
      reg(:multi_name).bit(:some_bit0, :xlah0, :xlah_blah0).write(1)
      reg(:multi_name).data.should == 3
      reg(:multi_name).bit(:some_bit2, :some_bit3, :some_bit4).write(3)
      reg(:multi_name).data.should == 0xF
    end

    it "the bits method accepts an array of bit ids" do
      reg :tr, 0 do
        bits 31..0, :data
      end

      reg(:tr).bits([4,5,6,7]).write(0xF)
      reg(:tr).data.should == 0x0000_00F0
    end

    it "the Reg.read method should accept a mask option" do
      reg :tr2, 0 do
        bits 31..0, :data
      end

      reg(:tr2).read!(0x1234_5678, mask: 0x0000_00F0)
      reg(:tr2).data.should == 0x1234_5678
      reg(:tr2).bit(0).is_to_be_read?.should == false
      reg(:tr2).bit(1).is_to_be_read?.should == false
      reg(:tr2).bit(2).is_to_be_read?.should == false
      reg(:tr2).bit(3).is_to_be_read?.should == false
      reg(:tr2).bit(4).is_to_be_read?.should == true
      reg(:tr2).bit(5).is_to_be_read?.should == true
      reg(:tr2).bit(6).is_to_be_read?.should == true
      reg(:tr2).bit(7).is_to_be_read?.should == true
      reg(:tr2).bit(8).is_to_be_read?.should == false
    end

    specify "clear_read_flag clears is_to_be_read status " do
      reg :tr3, 0 do
        bits 31..0, :data
      end

        reg(:tr3).read(0x0F)
        reg(:tr3).bit(0).is_to_be_read?.should == true
        reg(:tr3).bit(0).clear_read_flag
        reg(:tr3).bit(0).is_to_be_read?.should == false
    end

    specify "bit reset values can be specified as undefined or memory" do
      reg :reset1, 0 do
        bit 1, :x, reset: :undefined
        bit 0, :y, reset: :memory
      end

      reg :reset1a, 0 do
        bits 15..8, :x, reset: :undefined
        bits 7..0,  :y, reset: :memory
      end

      reg(:reset1).bit(:x).reset_val.should == :undefined
      reg(:reset1).bit(:y).reset_val.should == :memory
      # We still need to pick a data value (until Origen can truly model the concept of X)
      reg(:reset1).data.should == 0
      # But we can also tell that the true state is undefined 
      reg(:reset1).bit(:x).has_known_value?.should == false
      reg(:reset1).bit(:y).has_known_value?.should == false
      reg(:reset1).write(0xFFFF_FFFF)
      reg(:reset1).bit(:x).has_known_value?.should == true
      reg(:reset1).bit(:y).has_known_value?.should == true
      reg(:reset1).data.should == 3
      reg(:reset1).reset
      reg(:reset1).bit(:x).has_known_value?.should == false
      reg(:reset1).bit(:y).has_known_value?.should == false
      reg(:reset1).data.should == 0

      reg(:reset1a).bits(:x).reset_val.should == :undefined
      reg(:reset1a).bits(:y).reset_val.should == :memory
      reg(:reset1a).has_known_value?.should == false
      reg(:reset1a).bits(:x).has_known_value?.should == false
      reg(:reset1a).bits(:y).has_known_value?.should == false
    end

    specify "reset values can be set at register level" do
      reg :reset2, 0, reset: 0x3 do
        bit 3, :w
        bits 2..1, :x
        bit 0, :y
      end
      reg :reset3, 0, reset: :undefined do
        bit 1, :x
        bit 0, :y
      end
      reg :reset4, 0, reset: :memory do
        bit 1, :x
        bit 0, :y
      end
      reg :reset5, 0, reset: :memory do
        bit 1, :x
        bit 0, :y, reset: :undefined
      end

      reg(:reset2).data.should == 3
      reg(:reset3).bit(:x).reset_val.should == :undefined
      reg(:reset3).bit(:y).reset_val.should == :undefined
      reg(:reset4).bit(:x).reset_val.should == :memory
      reg(:reset4).bit(:y).reset_val.should == :memory
      reg(:reset5).bit(:x).reset_val.should == :memory
      reg(:reset5).bit(:y).reset_val.should == :undefined
    end

    specify "a memory location can be set on a register" do
      reg :reset6, 0, memory: 0x1234_0000 do
        bit 1, :x
        bit 0, :y
      end

      reg(:reset6).bit(:x).reset_val.should == :memory
      reg(:reset6).bit(:y).reset_val.should == :memory
      reg(:reset6).memory.should == 0x1234_0000
    end

    specify "access can be set and tested at reg level" do
      reg :access1, 0, access: :w1c do
        bits 2..1, :x
        bit  0,    :y
      end

      reg(:access1).bits(:x).w1c?.should == true
      reg(:access1).bit(:y).w1c?.should == true
      reg(:access1).w1c?.should == true
      reg(:access1).w1s?.should == false
      # Verify the access can be pulled for a mutli-bit collection
      reg(:access1).bits(:x).access.should == :w1c
    end

    specify "sub collections of bits can be made from bit collections" do
      reg :reg1, 0 do
        bits 31..0, :data
      end

      reg(:reg1)[:data].size.should == 32
      reg(:reg1)[31..0].size.should == 32
      reg(:reg1).bits(:data).size.should == 32
      reg(:reg1).bits(:data)[15..8].size.should == 8
      reg(:reg1).bits(:data)[15..8].write(0xFF)
      reg(:reg1).data.should == 0x0000_FF00
      reg(:reg1).reset
      # Verify that bits are stored in consistent order
      reg(:reg1).to_a.map {|b| b.position }.should == 
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
      reg(:reg1)[].to_a.map {|b| b.position }.should == 
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
      reg(:reg1)[15..0].to_a.map {|b| b.position }.should ==
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
      reg(:reg1)[][15..0].to_a.map {|b| b.position }.should ==
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
      reg(:reg1)[15..0][15..8].to_a.map {|b| b.position }.should ==
        [8, 9, 10, 11, 12, 13, 14, 15]
      reg(:reg1)[15..0][15..8][3..0].to_a.map {|b| b.position }.should ==
        [8, 9, 10, 11]

      reg(:reg1)[15..0][15..8][3..0].write(0xF)
      reg(:reg1).data.should == 0x0000_0F00

      # When 1 bit requested just return that bit, this is consistent with the original
      # behaviour before sub collections were added
      reg(:reg1).bits(:data)[15].class.should == Origen::Registers::Bit
      # Calling bits on a bit collection with no args should just return self
      reg(:reg1).bits(:data).bits.size.should == 32
    end

    specify "indexed references to missing bits should return nil" do
      reg :reg2, 0, size: 8 do
        bits 7..0, :data
      end
      reg(:reg2)[7].should be
      reg(:reg2)[8].should == nil
    end

    specify "reg dot syntax works" do
      reg :reg_dot1, 0, size: 8 do
        bits 7..0, :d1
      end
      reg_dot1.val.should == 0
      reg_dot1.d1.val.should == 0
    end

    specify "regs can be deleted" do
      class RegOwner
        include Origen::Model
        def initialize
          reg :reg1, 0, size: 8 do
            bits 7..0, :d1
          end
          reg :reg2, 0, size: 8 do
            bits 7..0, :d1
          end
          reg :reg3, 0, size: 8 do
            bits 7..0, :d1
          end
        end
      end
      top = RegOwner.new
      top.has_reg?(:reg1).should == true
      top.has_reg?(:reg2).should == true
      top.has_reg?(:reg3).should == true
      top.has_reg?(:reg4).should == false
      top.del_reg(:reg2)
      top.has_reg?(:reg1).should == true
      top.has_reg?(:reg2).should == false
      top.has_reg?(:reg3).should == true
      top.has_reg?(:reg4).should == false
      top.delete_registers
      top.has_reg?(:reg1).should == false
      top.has_reg?(:reg2).should == false
      top.has_reg?(:reg3).should == false
      top.has_reg?(:reg4).should == false
    end


    specify "regs can be Marshaled" do
      # Spec cannot be mashaled (as the reg owner) so embed the test
      # reg in a class which will marshal without error
      class RegOwner
        include Origen::Model
        def initialize
          reg :reg1, 0, size: 8 do
            bits 7..0, :d1
          end
        end
      end
      reg = RegOwner.new.reg1
      reg.data # Ensure the reg is materialized
      r = Marshal.load Marshal.dump reg
      r.d1.val.should == 0
    end

    specify "cloned regs inherit bit accessors" do
      reg :reg_dot3, 0, size: 8 do
        bits 7..0, :d1
      end
      c = reg_dot3.clone
      c.d1.val.should == 0
      reg_dot3.d1.write(5)
      reg_dot3.d1.data.should == 5
      c.d1.val.should == 0
    end

    specify "dot methods work in a class with method_missing" do
      class Base
        include Origen::Model

        def method_missing(method, *args, &block)
          if method == :blah
            "yo"
          else
            super
          end
        end

        def respond_to?(method)
          method == :blah || super(method)
        end
      end

      class RegOwner2 < Base
        def initialize
          reg :reg1, 0, size: 8 do
            bits 7..0, :d1
          end
        end
      end

      o = RegOwner2.new
      o.blah.should == "yo"
      o.reg1.data.should == 0
      o.respond_to?(:blah).should == true
      o.respond_to?(:reg1).should == true
      o.respond_to?(:reg2).should == false
    end

    specify "block read/write method can set/read bits" do
      add_reg :blregtest,   0x00,  4,  :y       => { :pos => 0},
                                       :x       => { :pos => 1, :bits => 2 },
                                       :w       => { :pos => 3 }
      reg(:blregtest).data.should == 0x0
      reg(:blregtest).write! do |r|
        r.bits(:y).write(1)
        r.bits(:x).write(0x2)
        r.bits(:w).write(1)
      end
      reg(:blregtest).data.should == 0xD

      reg(:blregtest).write(0)
      reg(:blregtest).x.write! do |b|
        b[1].write(1)
      end
      reg(:blregtest).data.should == 0b0100

      reg(:blregtest).read! do |r|
        r.bits(:y).read
      end      
      reg(:blregtest).bits(:y).is_to_be_read?.should == true
      reg(:blregtest).bits(:x).is_to_be_read?.should == false
      reg(:blregtest).bits(:w).is_to_be_read?.should == false
    end

    it "write method can override a read-only register bitfield with :force = true" do
        reg :reg, 0x0, 32, description: 'reg' do
            bits 7..0,   :field1, reset: 0x0, access: :rw
            bits 15..8,  :field2, reset: 0x0, access: :ro
            bits 23..16, :field3, reset: 0x0, access: :ro
            bits 31..24, :field4, reset: 0x0, access: :rw
        end
        reg(:reg).bits(:field1).write(0xf)
        reg(:reg).bits(:field2).write(0xf)
        reg(:reg).bits(:field3).write(0xf)
        reg(:reg).bits(:field4).write(0xf)
        reg(:reg).bits(:field1).data.should == 0xf
        reg(:reg).bits(:field2).data.should == 0x0
        reg(:reg).bits(:field3).data.should == 0x0
        reg(:reg).bits(:field4).data.should == 0xf

        reg(:reg).bits(:field1).write(0xa, force: true)
        reg(:reg).bits(:field2).write(0xa, force: true)
        reg(:reg).bits(:field3).write(0xa, force: true)
        reg(:reg).bits(:field4).write(0xa, force: true)
        reg(:reg).bits(:field1).data.should == 0xa
        reg(:reg).bits(:field2).data.should == 0xa
        reg(:reg).bits(:field3).data.should == 0xa
        reg(:reg).bits(:field4).data.should == 0xa
    end

    it 'regs with all bits writable can be created via a shorthand' do
      class RegBlock
        include Origen::Model
        def initialize
          reg :reg1, 0
          reg :reg2, 4, size: 8
          reg :reg3, 5, size: 8, reset: 0xFF
        end
      end

      b = RegBlock.new
      b.reg1.size.should == 32
      b.reg2.size.should == 8
      b.reg1.write(0xFFFF_FFFF)
      b.reg1.data.should == 0xFFFF_FFFF
      b.reg2.write(0xFF)
      b.reg2.data.should == 0xFF
      b.reg3.data.should == 0xFF
    end

    it 'regs can shift left' do
      reg :sr1, 0, size: 4
      sr1.write(0xF)
      sr1.data.should == 0b1111
      sr1.shift_left
      sr1.data.should == 0b1110
      sr1.shift_left
      sr1.data.should == 0b1100
      sr1.shift_left(1)
      sr1.data.should == 0b1001
      sr1.shift_left(1)
      sr1.data.should == 0b0011
    end

    it 'regs can shift right' do
      reg :sr2, 0, size: 4
      sr2.write(0xF)
      sr2.data.should == 0b1111
      sr2.shift_right
      sr2.data.should == 0b0111
      sr2.shift_right
      sr2.data.should == 0b0011
      sr2.shift_right(1)
      sr2.data.should == 0b1001
      sr2.shift_right(1)
      sr2.data.should == 0b1100
    end

    it 'regs can be frozen' do
      reg :frz1, 0, size: 4
      frz1.write(0xF)
      frz1.data.should == 0b1111
      frz1.freeze
      frz1.frozen?.should == true
    end

    it 'the original reg definition API still works' do
      add_reg :mclkdiv2,   0x03,  16,  :osch       => { :pos => 15 },
                                       :asel       => { :pos => 14 },
                                       :failctl    => { :pos => 13 },
                                       :parsel     => { :pos => 12 },
                                       :eccen      => { :pos => 11 },
                                       :cmdloc     => { :pos => 8, :bits => 3, :res => 0b001 },
                                       :clkdiv     => { :pos => 0, :bits => 8, :res => 0x18 }
      mclkdiv2.clkdiv.size.should == 8
      mclkdiv2.clkdiv.data.should == 0x18
      mclkdiv2.data.should == 0x0118
    end

    it "read only bits can be forced to write" do
      add_reg :ro_test, 0, access: :ro
      ro_test.write(0xFFFF_FFFF)
      ro_test.data.should == 0
      ro_test.write(0xFFFF_FFFF, force: true)
      ro_test.data.should == 0xFFFF_FFFF
      # Read requests apply force by default
      ro_test.read(0x5555_5555)
      ro_test.data.should == 0x5555_5555
    end

    it "inverse and reverse data methods work" do
      add_reg :revtest, 0
      revtest.write(0x00FF_AA55)
      revtest.data.should == 0x00FF_AA55
      revtest.data_b.should == 0xFF00_55AA
      revtest.data_reverse.should == 0xAA55_FF00
    end

    it "multi-named bit collections work" do
      add_reg :mnbit,   0x03,  8,  :d  => { pos: 6, bits: 2 },
                                   :b  => { pos: 4, bits: 2 },
                                   :c  => { pos: 2, bits: 2 },
                                   :a  => { pos: 0, bits: 2 }

      mnbit.data.should == 0
      mnbit.bits(:d, :a).write(0b0110)
      mnbit.d.data.should == 0b01
      mnbit.a.data.should == 0b10
      mnbit.data.should == 0b01000010
      mnbit.write(0)
      mnbit.bits(:b, :c).write(0b0110)
      mnbit.b.data.should == 0b01
      mnbit.c.data.should == 0b10
      mnbit.data.should == 0b00011000
    end

    it "regs can be grabbed using regular expression" do
      class RegOwner
        include Origen::Model
        def initialize
          reg :adc0_cfg, 0, size: 8 do
            bits 7..0, :d1
          end
          reg :adc1_cfg, 0, size: 8 do
            bits 7..0, :d1
          end
          reg :dac_cfg, 0, size: 8 do
            bits 7..0, :d1
          end
        end
      end
      top = RegOwner.new
      top.regs.inspect.should == "[:adc0_cfg, :adc1_cfg, :dac_cfg]"
      top.regs('/adc\d_cfg/').inspect.should == "[:adc0_cfg, :adc1_cfg]"
      top.regs('/cfg/').inspect.should == "[:adc0_cfg, :adc1_cfg, :dac_cfg]"
      expected_output = <<-EOT
[
0x0 - :dac_cfg
  \u2552\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2564\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2564\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2564\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2564\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2564\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2564\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2564\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2555
  \u2502      7      \u2502      6      \u2502      5      \u2502      4      \u2502      3      \u2502      2      \u2502      1      \u2502      0      \u2502
  \u2502                                                    d1[7:0]                                                    \u2502
  \u2502                                                      0x0                                                      \u2502
  \u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518]
  EOT
      expect do
        top.regs('/dac/').show
      end.to output(expected_output).to_stdout
    end
  end
end
