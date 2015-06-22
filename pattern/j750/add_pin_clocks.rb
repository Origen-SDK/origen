# This pattern exercises the methods related to pin clocks
Pattern.create do

  #################################################
  # TEST A.
  #################################################
  Origen.tester.set_timeset("intram", 40)
  Origen.tester.cycle(:repeat => 100)
  $dut.pins(:clk).enable_clock(frequency_in_mhz: 2)
  $dut.pins(:clk).start_clock
  Origen.tester.cycle(:repeat => 50)
  Origen.tester.cycle(:repeat => 47)
  Origen.tester.cycle(:repeat => 3)
  $dut.pins(:clk).stop_clock
  Origen.tester.cycle(:repeat => 100)


  #################################################
  # TEST B.  
  #################################################
  $dut.pins(:clk).start_clock
  100.times do
    Origen.tester.cycle
  end
  $dut.pins(:clk).stop_clock
  Origen.tester.cycle(:repeat => 100)


  #################################################
  # TEST C.  
  #################################################
  $dut.pins(:clk_mux).enable_clock(frequency_in_mhz: 1)
  $dut.pins(:clk_mux).start_clock
  $dut.pins(:clk).resume_clock
  Origen.tester.cycle(:repeat => 100)
  $dut.pins(:clk).pause_clock
  Origen.tester.cycle(:repeat => 100)
  $dut.pins(:clk_mux).stop_clock
  Origen.tester.cycle(:repeat => 100)


  #################################################
  # TEST D.  
  #################################################
  $dut.pins(:clk).resume_clock(frequency_in_khz: 500)
  Origen.tester.cycle(:repeat => 100)
  Origen.tester.set_timeset("intram_fast", 20)
  Origen.tester.cycle(:repeat => 100)
  Origen.tester.set_timeset("intram_slow", 100)
  Origen.tester.cycle(:repeat => 100)
  $dut.pins(:clk).pause_clock
  Origen.tester.cycle(:repeat => 100)
  Origen.tester.set_timeset("intram", 40)
  $dut.pins(:clk).resume_clock
  Origen.tester.cycle(:repeat => 100)
  $dut.pins(:clk).pause_clock
  $dut.pins(:clk).disable_clock


end
