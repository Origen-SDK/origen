$tester = (options[:tester] || RGen::Tester::J750).new
if options[:version]
  # $top is used here instead of $dut to test that RGen will provide
  # the $dut alias automatically
  $top    = options[:dut].new(options[:version])
else
  $top    = options[:dut].new
end
RGen.mode = :debug
