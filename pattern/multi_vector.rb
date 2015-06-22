class SetupTester
  include Origen::PersistentCallbacks

  def before_pattern(pattern_name)
    case
    when pattern_name =~ /^nvm_single\./
      $tester.vector_group_size = 1
    when pattern_name =~ /^nvm_dual\./
      $tester.vector_group_size = 2
    when pattern_name =~ /^nvm_quad\./
      $tester.vector_group_size = 4
    else
      # To avoid breaking later tests
      $tester.vector_group_size = 1
    end
  end
end
SetupTester.new

[:single, :dual, :quad].each do |name|
  # Startup is being skipped here since it is currently a test of the ability
  # to render (i.e. paste) vectors, therefore they are not compressible by
  # Origen and which makes debugging this confusing!
  Pattern.create(name: name, skip_startup: true) do
    $tester.set_timeset("nvmbist", 40)

    ss "$tester.cycle(repeat: 128)"
    $tester.cycle(repeat: 128)

    ss do
      cc "64.times do"
      cc "  $dut.pin(:clk).drive!(0)"
      cc "  $dut.pin(:clk).drive!(1)"
      cc "end"
    end
    64.times do
      $dut.pin(:clk).drive!(0)
      $dut.pin(:clk).drive!(1)
    end
  end
end
