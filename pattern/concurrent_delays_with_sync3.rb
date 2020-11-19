def sync_all
  PatSeq.sync_up
end

Pattern.sequence do |seq|
  10.ms!

  seq.thread :th1 do
    10.ms!
    sync_all
    10.ms!
  end

  seq.thread :th2 do
    # This should block for 10ms until th1 reaches the sync_up point
    sync_all
    20.ms!
  end

  5.ms!
end

