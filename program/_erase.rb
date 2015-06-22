# A sub flow is a flow like any other.
# However the name should begin with 
# _ to indicate that it is a sub
# flow  this will prevent it being
# generated as a top-level flow by 
# Origen.
# Any arguments passed in when
# instantiating this flow will be available via a hash as the second
# argument, here called options, although the naming is arbitrary.
Flow.create do |options|

  # Define default options
  options = { :pulses => 4,
              :post_verify => true,
  }.merge(options)

  options[:pulses].times do
    func :erase_all
  end
  
  if options[:post_verify]
    import "erase_vfy"
  end
  
end
