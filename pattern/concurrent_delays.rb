Pattern.sequence do |seq|
  10.ms!

  seq.thread :th1 do
    10.ms!
  end

  seq.thread :th2 do
    20.ms!
  end

  5.ms!
end
