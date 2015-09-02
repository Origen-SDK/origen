Pattern.create do

  ss "Test that comments work"
  cc "Hello"

  ss "Test that writing explicit content works"
  $tester.direct_write "R0   // Put the part in reset"

  ss "Test that delay works"
  cc "This should sleep for 40 cycles"
  $tester.wait(:time_in_ms => 40)
  cc "This should sleep for 1000 cycles"
  $tester.wait(:time_in_s => 1)
  cc "This should sleep for 20 cycles"
  $tester.wait(:cycles => 20)

  ss "Test write_byte"
  $tester.write_byte(0x55, address: 0x12)

  ss "Test write_word"
  $tester.write_word(0xAA55, address: 0x34)

  ss "Test write_longword"
  $tester.write_longword(0x1122_AA55, address: 0x5678)

  ss "Test read"
  $tester.read(10, address: 0x0001234, size: 8)

end
