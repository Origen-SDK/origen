Resources.create do |options|

  options = { :number => 2,
  }.merge(options)

  options[:number].times do |x|
    func "bitcell_iv_#{x}"
  end

end
