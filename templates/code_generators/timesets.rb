<% unless @dut_generator -%>
# ******************************************************************************
# Any timesets defined in this file will be added to ALL of your DUT targets!!!!
# ******************************************************************************

<% end -%>
# For more examples see: https://origen-sdk.org/origen/guides/pattern/timing/#Complex_Timing 

# By default, all pins will drive for the whole period on drive cycles and strobe at 50%
# of the period on compare cycles, this can be overridden for all or specific pins as shown
# in the examples below.

# Example definition, defines an alternative default compare wave for all pins and specific
# drive timing for :tck
# dut.timeset :func do |t|
#   t.compare_wave do |w|
#     w.compare :data, at: "period / 4"
#   end
# 
#   t.drive_wave :tck do |w|
#      w.drive :data, at: 0
#      w.drive 0, at: 25
#      w.dont_care at: "period - 10"  # Just to show that dont_care can be used
#   end
# end
