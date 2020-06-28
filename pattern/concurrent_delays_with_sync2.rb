Pattern.sequence do |seq|
  10.ms!

  seq.thread :th1 do
    10.ms!
  end

  seq.thread :th2 do
    PatSeq.wait_for_thread_to_complete :th1
    20.ms!
  end

  PatSeq.wait_for_threads_to_complete :all

  5.ms!
end
