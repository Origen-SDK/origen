Pattern.sequence do |seq|
  10.ms!

  seq.in_parallel :th1 do
    10.ms!
  end

  seq.in_parallel :th2 do
    20.ms!
  end

  5.ms!
end
