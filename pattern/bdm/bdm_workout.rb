Pattern.create do

  ss "Test that comments work"
  cc "Hello"

  ss "Test that writing explicit content works"
  $tester.direct_write "R0   // Put the part in reset"

  ss "Test that delay works"
  cc "This should sleep for no cycles"
  $tester.wait(:time_in_ms => 99)
  cc "This should sleep for 1 cycle"
  $tester.wait(:time_in_ms => 100)
  cc "This should sleep for 10 cycles"
  $tester.wait(:time_in_s => 1)
  cc "This should sleep for 20 cycles"
  $tester.wait(:cycles => 20)

  ss "Test write_byte"
  $tester.write_byte(0x12, 0x55)

  ss "Test write_word"
  $tester.write_word(0x34, 0xAA55)

end
