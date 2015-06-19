# This pattern exercises the methods related to pin clocks
Pattern.create do

  #################################################
  # TEST A.
  #################################################
  RGen.tester.set_timeset("intram", 40)
  RGen.tester.cycle(:repeat => 100)
  $dut.pins(:clk).enable_clock(frequency_in_mhz: 2)
  $dut.pins(:clk).start_clock
  RGen.tester.cycle(:repeat => 50)
  RGen.tester.cycle(:repeat => 47)
  RGen.tester.cycle(:repeat => 3)
  $dut.pins(:clk).stop_clock
  RGen.tester.cycle(:repeat => 100)


  #################################################
  # TEST B.  
  #################################################
  $dut.pins(:clk).start_clock
  100.times do
    RGen.tester.cycle
  end
  $dut.pins(:clk).stop_clock
  RGen.tester.cycle(:repeat => 100)


  #################################################
  # TEST C.  
  #################################################
  $dut.pins(:clk_mux).enable_clock(frequency_in_mhz: 1)
  $dut.pins(:clk_mux).start_clock
  $dut.pins(:clk).resume_clock
  RGen.tester.cycle(:repeat => 100)
  $dut.pins(:clk).pause_clock
  RGen.tester.cycle(:repeat => 100)
  $dut.pins(:clk_mux).stop_clock
  RGen.tester.cycle(:repeat => 100)


  #################################################
  # TEST D.  
  #################################################
  $dut.pins(:clk).resume_clock(frequency_in_khz: 500)
  RGen.tester.cycle(:repeat => 100)
  RGen.tester.set_timeset("intram_fast", 20)
  RGen.tester.cycle(:repeat => 100)
  RGen.tester.set_timeset("intram_slow", 100)
  RGen.tester.cycle(:repeat => 100)
  $dut.pins(:clk).pause_clock
  RGen.tester.cycle(:repeat => 100)
  RGen.tester.set_timeset("intram", 40)
  $dut.pins(:clk).resume_clock
  RGen.tester.cycle(:repeat => 100)
  $dut.pins(:clk).pause_clock
  $dut.pins(:clk).disable_clock


end
