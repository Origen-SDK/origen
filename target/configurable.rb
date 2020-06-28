(options[:tester] || OrigenTesters::J750).new
if options[:version]
  options[:dut].new(options[:version])
else
  options[:dut].new
end
tester.set_timeset('func', 40)
Origen.mode = :debug
