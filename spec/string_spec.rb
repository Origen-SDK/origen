require 'spec_helper'

describe String do

  specify "camel case works" do

    "hello_to_you_all".camelcase.should == "HelloToYouAll"

    # This all-in-one form is deprecated
    #"and to You to".camel_case.should == "AndToYouTo"
    "and to You to".gsub(" ", "_").camelcase.should == "AndToYouTo"

  end

  specify "can be chunked to lines of a specific length at word boundaries" do
    s = "eSHDC, eSPI, DMA, MPIC, GPIO, system control and power management, clocking, debug, IFC, DDRCLK supply, and JTAG I/O voltage"
    s.to_lines(60).should ==
      ["eSHDC, eSPI, DMA, MPIC, GPIO, system control and power",
       "management, clocking, debug, IFC, DDRCLK supply, and JTAG",
       "I/O voltage"]
  end

  specify "squeeze lines works" do
    "General-Purpose POR Configuration\n       Register".squeeze_lines.should == 'General-Purpose POR Configuration Register'
  end

  specify 'is_numeric? works' do
    '1'.is_numeric?.should == true
    '1.2'.numeric?.should == true
    '5.4e-29'.numeric?.should == true
    '12e20'.numeric?.should == true
    '1a'.numeric?.should == false
    '1.2.3.4'.numeric?.should == false
    'a'.numeric?.should == false
  end

  specify 'titleize works' do
    'Brian is_a dull-boy, TOO bad for dng'.titleize.should == 'Brian Is A Dull Boy, Too Bad For Dng'
    'Brian is_a dull-boy, TOO bad for dng'.titleize(keep_specials: true).should == 'Brian Is_a Dull-boy, Too Bad For Dng'
  end
  
  specify 'convert hex, octal, dec, binary strings to decimal' do
    "0xA6".to_dec.should == 166
    "0d166".to_dec.should == 166
    "0b10100110".to_dec.should == 166
    "0o246".to_dec.should == 166  
  end
  
  specify 'convert verilog numbers, represented as string, to an integer' do
    "10100110".to_dec.should == 166
    "b10100110".to_dec.should == 166
    "o246".to_dec.should == 166
    "d166".to_dec.should == 166
    "hA6".to_dec.should == 166
    "8'b10100110".to_dec.should == 166
    "8'o246".to_dec.should == 166
    "8'd166".to_dec.should == 166
    "8'hA6".to_dec.should == 166
  end
  
  specify 'correctly converts signed verilog numbers to an integer' do
    "8'shA6".to_dec.should == -166
    "9'shA6".to_dec.should == 166
  end
  
  specify 'can correctly identify a verilog number' do
    "10100110".is_verilog_number?.should == true
    "b10100110".is_verilog_number?.should == true
    "o246".is_verilog_number?.should == true
    "d166".is_verilog_number?.should == true
    "hA6".is_verilog_number?.should == true
    "8'b10100110".is_verilog_number?.should == true
    "8'o246".is_verilog_number?.should == true
    "8'd166".is_verilog_number?.should == true
    "8'hA6".is_verilog_number?.should == true
    "0x1234".is_verilog_number?.should == false
    "12".is_verilog_number?.should == false
  end
end
