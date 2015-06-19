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
end
