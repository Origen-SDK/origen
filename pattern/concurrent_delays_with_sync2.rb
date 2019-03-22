Pattern.sequence do |seq|
  10.ms!

  seq.thread :th1 do
    10.ms!
  end

  seq.thread :th2 do
    seq.wait_for_thread :th1
    20.ms!
  end

  seq.wait_for_threads :all

  5.ms!
end
