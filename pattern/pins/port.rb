# This pattern exercises the methods in the Origen::Pins::Port class
Pattern.create do

  ss "Test that toggle works"
  cc "There should be 10 vectors here with alternating port A"
  dut.nvm.pins(:porta).drive(0x55)
  10.cycles do 
   dut.nvm.pins(:porta).toggle
  end 

  ss "Test that toggle! works"
  cc "There should be 3 vectors here with alternating port A"
  dut.nvm.pins(:porta).toggle!
  dut.nvm.pins(:porta).toggle!
  dut.nvm.pins(:porta).toggle!

  ss "Test that comparing works, port A should expect 0x3F"
  dut.nvm.pins(:porta).assert!(0x3F)

  ss "Test that little endian works"
  cc "In the following vectors port b should be the little endian"
  cc "representation of port a"
  dut.nvm.pins(:porta).drive(0x3F)
  dut.nvm.pins(:portb).drive(0x3F)
  $tester.cycle
  dut.nvm.pins(:porta).compare(dut.nvm.pins(:porta).data_b)
  dut.nvm.pins(:portb).compare(dut.nvm.pins(:portb).data_b)
  $tester.cycle
  dut.nvm.pins(:porta).drive(0x12)
  dut.nvm.pins(:portb).drive(0x12)
  $tester.cycle

  ss "Test that aliasing a port pin works"
  cc "In the following vector PORT A5 should be opposite state from the rest"
  dut.nvm.pins(:porta).drive(0x00)
  dut.pin(:pa5).drive!(1)
  dut.nvm.pins(:porta).assert(0xFF)
  dut.pin(:pa5).assert!(0)

  ss "Test that aliasing a port works"
  cc "In the following vectors PORTA should toggle"
  dut.pins(:porta_alias).drive!(0xAA)
  dut.pins(:porta_alias).drive!(0x55)

  ss "Test that aliasing multiple pins within a port works"
  cc "In the following vectors the nibbles of PORTA should be in opposite states"
  dut.pins(:pa_lower).drive(0x0)
  dut.pins(:pa_upper).drive!(0xF)
  dut.pins(:pa_lower).assert(0xF)
  dut.pins(:pa_upper).assert!(0x0)

end
