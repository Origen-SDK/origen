def sync_up
  PatSeq.sync_up(:th1, :th2)
end

Pattern.sequence do |seq|
  10.ms!

  seq.thread :th1 do
    10.ms!
    sync_up
    10.ms!
  end

  seq.thread :th2 do
    # This should block for 10ms until th1 reaches the sync_up point
    sync_up
    20.ms!
  end

  seq.thread :th3 do
    # This should not block since :th3 is not in the list
    sync_up
    20.ms!
  end

  5.ms!
end

