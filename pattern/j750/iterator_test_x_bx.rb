Pattern.create(:by_block => true, :by_setting => [1,2,3,4,5]) do |block, setting|

  cc block.id
  $tester.cycle
  cc setting
  $tester.cycle

end
