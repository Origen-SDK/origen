require "spec_helper"

describe 'Ruby Core Extension Specs' do
  context "with 'default' target" do
    before(:each) { load_target('default') }

    describe Object do
      describe '#origen_subblock?' do
        it 'returns true if the given object inherits from either Origen::Model or Origen::Controller' do
          expect(dut.nvm.origen_subblock?).to be(true)
        end
        
        it 'returns false if the given object does not inherit from either Origen::Model or Origen::Controller' do
          expect(5.origen_subblock?).to be(false)
          expect('hello'.origen_subblock?).to be(false)
          expect(Origen.origen_subblock?).to be(false)
          expect(Origen.app.origen_subblock?).to be(false)
          expect(dut.nvm.class.origen_subblock?).to be(false)
        end
      end
    end
    
    describe Integer do
      describe "Width" do
        before(:all) do
          @old_width = Integer.width
          Integer.width = 32
        end

        it 'has a default width of 32-bit' do
          expect(Integer.width).to eql(32)
        end
        
        it 'allows the size to be customized' do
          expect(Integer.width).to eql(32)
          Integer.width = 64
          expect(Integer.width).to eql(64)
          Integer.width = 8
          expect(Integer.width).to eql(8)
        end
        
        after(:all) do
          Integer.width = @old_width
        end
      end
      
      describe "2's Complement" do
        before(:all) do
          @old_width = Integer.width
          Integer.width = 32
        end
        
        before(:each) do
          Integer.width = 32
        end

        it "can calculate the 2's complement of an integer" do
          expect(0.twos_complement).to eql(0b0)
          expect(1.twos_complement).to eql(0b1)
          expect(2.twos_complement).to eql(0b10)
          expect(-1.twos_complement).to eql(0b1111_1111_1111_1111_1111_1111_1111_1111)
          expect(-2.twos_complement).to eql(0b1111_1111_1111_1111_1111_1111_1111_1110)
          expect(2147483647.twos_complement).to eql(0b0111_1111_1111_1111_1111_1111_1111_1111)
          expect(-2147483648.twos_complement).to eql(0b1000_0000_0000_0000_0000_0000_0000_0000)
        end

        it "allows the width to be overridden" do
          expect(0.twos_complement(8)).to eql(0b0)
          expect(1.twos_complement(8)).to eql(0b1)
          expect(2.twos_complement(8)).to eql(0b10)
          expect(-1.twos_complement(8)).to eql(0b1111_1111)
          expect(-2.twos_complement(8)).to eql(0b1111_1110)
          expect(-1.twos_complement(16)).to eql(0b1111_1111_1111_1111)
          expect(-2.twos_complement(16)).to eql(0b1111_1111_1111_1110)
        end
        
        it "uses the default width from Integer" do
          Integer.width = 8
          expect(-1.twos_complement).to eql(0b1111_1111)
          expect(-2.twos_complement).to eql(0b1111_1110)

          Integer.width = 12
          expect(-1.twos_complement).to eql(0b1111_1111_1111)
          expect(-2.twos_complement).to eql(0b1111_1111_1110)
        end

        it "raises an error if the integer cannot fit within the desired bits" do
          expect {
            2147483648.twos_complement
          }.to raise_error(RangeError, "Integer 2147483648 cannot fit into 32 bits with 2s complement encoding")
          
          expect {
            -2147483649.twos_complement
          }.to raise_error(RangeError, "Integer -2147483649 cannot fit into 32 bits with 2s complement encoding")
        end
        
        after(:all) do
          Integer.width = @old_width
        end
      end
    end
  end
end
