require "spec_helper"

include Origen::Pins

describe "Tester Definition" do

  before :each do
    Origen.load_application
  end

  it "select J750 tester properly" do
    Origen.target.temporary = "debug"
    Origen.target.load!
    $tester.name.should == "j750"
    $tester.respond_to?('hpt_mode').should == false
  end

  it "select J750 HPT tester properly" do
    Origen.target.temporary = "hpt"
    Origen.target.load!
    $tester.name.should == "j750_hpt"
    $tester.class.hpt_mode.should == true
  end

  it "tester pattern microcodes" do
    Origen.target.temporary = "debug"
    Origen.target.load!

    $tester.cycle

    # memory testing
    if ($tester.respond_to?('memory_test'))
      $tester.memory_test
      $tester.cycle
      $tester.memory_test(
             init_counter_x: true,
             init_counter_y: true,
             inc_counter_x: true,
             inc_counter_y: true)
      $tester.cycle
      $tester.memory_test(capture_vector: true)
      $tester.cycle
      $tester.memory_test(capture_vector_mem0: true)
      $tester.cycle
      $tester.memory_test(capture_vector_mem1: true)
      $tester.cycle
      $tester.memory_test(capture_vector_mem2: true)
      $tester.cycle
      $tester.memory_test(gen_vector: false)
      $tester.cycle
      $tester.memory_test(pin: :reset)
      $tester.cycle
      $tester.memory_test(gen_vector: true, pin: $nvm.pin(:reset), pin_data: :drive)
      $tester.cycle
      $tester.memory_test(gen_vector: true, pin: $nvm.pin(:reset), pin_data: :expect)
      $tester.cycle
    end

    # Storing
    $tester.store
    $tester.cycle

    # subroutines 
    if ($tester.respond_to?('call_subroutine'))
      $tester.start_subroutine('dummysubr')
      $tester.cycle
      $tester.end_subroutine
      $tester.cycle
      $tester.call_subroutine('dummysubr')
      $tester.cycle
      $tester.start_subroutine('dummysubr2')
      $tester.cycle
      $tester.end_subroutine(true)
      $tester.cycle
    end

    if ($tester.respond_to?('enable_flag'))
      $tester.enable_flag(flagnum: 1)
      $tester.cycle
      $tester.enable_flag(flagnum: 2)
      $tester.cycle
      $tester.enable_flag(flagnum: 3)
      $tester.cycle
      $tester.enable_flag(flagnum: 4)
      $tester.cycle
      puts "******************** Invalid flag error expected here ********************"
      lambda { $tester.enable_flag(flagnum: 5) }.should raise_error
    end

    if ($tester.respond_to?('set_flag'))
      $tester.set_flag(flagnum: 1)
      $tester.cycle
      $tester.set_flag(flagnum: 2)
      $tester.cycle
      $tester.set_flag(flagnum: 3)
      $tester.cycle
      $tester.set_flag(flagnum: 4)
      $tester.cycle
      puts "******************** Invalid flag error expected here ********************"
      lambda { $tester.set_flag(flagnum: 5) }.should raise_error
    end

  end


end
