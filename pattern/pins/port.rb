# This pattern exercises the methods in the Origen::Pins::Port class
Pattern.create do

  ss "Test that toggle works"
  cc "There should be 10 vectors here with alternating port A"
  $nvm.pins(:porta).drive(0x55)
  10.cycles do 
   $nvm.pins(:porta).toggle
  end 

  ss "Test that toggle! works"
  cc "There should be 3 vectors here with alternating port A"
  $nvm.pins(:porta).toggle!
  $nvm.pins(:porta).toggle!
  $nvm.pins(:porta).toggle!

  ss "Test that comparing works, port A should expect 0x3F"
  $nvm.pins(:porta).assert!(0x3F)

  ss "Test that little endian works"
  cc "In the following vectors port b should be the little endian"
  cc "representation of port a"
  $nvm.pins(:porta).drive(0x3F)
  $nvm.pins(:portb).drive(0x3F)
  $tester.cycle
  $nvm.pins(:porta).compare($nvm.pins(:porta).data_b)
  $nvm.pins(:portb).compare($nvm.pins(:portb).data_b)
  $tester.cycle
  $nvm.pins(:porta).drive(0x12)
  $nvm.pins(:portb).drive(0x12)
  $tester.cycle

  ss "Test that aliasing a port pin works"
  cc "In the following vector PORT A5 should be opposite state from the rest"
  $nvm.pins(:porta).drive(0x00)
  $soc.pin(:pa5).drive!(1)
  $nvm.pins(:porta).assert(0xFF)
  $soc.pin(:pa5).assert!(0)

  ss "Test that aliasing a port works"
  cc "In the following vectors PORTA should toggle"
  $soc.pins(:porta_alias).drive!(0xAA)
  $soc.pins(:porta_alias).drive!(0x55)

  ss "Test that aliasing multiple pins within a port works"
  cc "In the following vectors the nibbles of PORTA should be in opposite states"
  $soc.pins(:pa_lower).drive(0x0)
  $soc.pins(:pa_upper).drive!(0xF)
  $soc.pins(:pa_lower).assert(0xF)
  $soc.pins(:pa_upper).assert!(0x0)

end
