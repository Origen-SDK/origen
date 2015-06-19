# This pattern exercises the methods in the RGen::Tester::Timing module
def gen_vectors
  2.times do
    $nvm.pin(:invoke).drive(0)
    $tester.cycle
    $nvm.pin(:invoke).drive(1)
    $tester.cycle
  end
end
Pattern.create do

  ss "Test ability to switch timesets"

  cc "These vectors should use timeset nvm_slow"
  $tester.set_timeset("nvm_slow", 200)
  gen_vectors
  cc "These vectors should use timeset nvm_fast"
  $tester.set_timeset("nvm_fast", 40)
  gen_vectors

  ss "Test ability to switch timesets within a block"
  cc "These vectors should use timeset nvm_slow"
  $tester.set_timeset("nvm_slow", 200) do
    gen_vectors
  end
  cc "These vectors should use timeset nvm_fast"
  gen_vectors

  ss "Test ability to call a set timeset block with no arguments"
  cc "These vectors should use timeset nvm_fast"
  $tester.set_timeset(nil) do
    gen_vectors
  end
  cc "These vectors should use timeset nvm_fast"
  gen_vectors

  ss "Test ability to call with a single array argument"
  cc "These vectors should use timeset nvm_slow"
  $tester.set_timeset(["nvm_slow", 40]) do
    gen_vectors
  end
  cc "These vectors should use timeset nvm_fast"
  gen_vectors
  cc "These vectors should use timeset nvm_fast"
  $tester.set_timeset([]) do
    gen_vectors
  end
  cc "These vectors should use timeset nvm_fast"
  gen_vectors

  ss "Test that delay calculations are based on the current timeset period"

  cc "This should wait for 5 cycles, 1000/200"
  $tester.set_timeset("nvm_slow", 200)
  $tester.wait(:time_in_ns => 1000)
  cc "This should wait for 25 cycles, 1000/40"
  $tester.set_timeset("nvm_fast", 40)
  $tester.wait(:time_in_ns => 1000)

  ss "Test the period counter"
  cc "This should generate a sequence with a clock pulse on the clk"
  cc "pin with period of 1 ms, and overall duration 10 ms"
  $nvm.pin(:clk).drive(0)
  $tester.count(:period_in_ms => 1, :duration_in_ms => 10) do
    $nvm.pin(:clk).drive!(1)
    $nvm.pin(:clk).drive(0)
  end

  ss "Test that Fixnum.cycles works"
  cc "There should be 10 cycles here"
  10.cycles

end
