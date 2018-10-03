<% unless @dut_generator -%>
# ********************************************************************************
# Any parameters defined in this file will be added to ALL of your DUT targets!!!!
# ********************************************************************************

<% end -%>
# For more examples see: https://origen-sdk.org/origen/guides/models/parameters/

# Example of how to define a default parameters set
# dut.define_params :default do |params|
#   params.tread = 40.nS
#   params.tprog = 20.uS
#   params.terase = 100.mS
# end

# Example of how to inherit and modify the defaults to create an alternative parameters set
# dut.define_params :probe, inherit: :default do |parent, params|
#   params.tprog = parent.tprog / 2
#   params.terase = 20.mS
# end
