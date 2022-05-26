require "spec_helper"

describe "Utilities" do

  class UDut
    include Origen::Model
    def initialize
      add_reg :d, 0
      add_reg :d1, 0, size: 35
    end
  end

  # Import collector specs
  include_examples :utility_collector_spec

  it "Origen::Utility.read_hex" do
    dut = UDut.new
    reg = dut.d
    u = Origen::Utility

    u.read_hex(0x55).should == "0x55"
    u.read_hex(nil).should == "0xX"
    u.read_hex(reg).should == "0xXXXXXXXX"
    reg[7..4].store
    u.read_hex(reg).should == "0xXXXXXXSX"
    reg[23..16].read
    u.read_hex(reg).should == "0xXX00XXSX"
    reg[23..16].read(0x12)
    u.read_hex(reg).should == "0xXX12XXSX"
    reg[31..28].overlay("sub")
    reg[31..28].read
    u.read_hex(reg).should == "0xVX12XXSX"
    reg[5].clear_flags
    u.read_hex(reg).should == "0xVX12XX_ssxs_X"
    reg[21].overlay("sub")
    reg[18].store
    u.read_hex(reg).should == "0xVX_00v1_0s10_XX_ssxs_X"

    # Test it can handle non-nibble-aligned regs
    u.read_hex(dut.d1).should == "0xXXXXXXXXX"
    dut.d1[3..0].read
    u.read_hex(dut.d1).should == "0xXXXXXXXX0"
  end
  
  it "Can create net smtp object" do
	require 'net/smtp'
	smtp = Net::SMTP.new('dummy', '0.0')
	smtp.is_a?(Net::SMTP).should == true
  end
end
