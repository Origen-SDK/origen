# ********************************************************************************
# Any registers defined in this file will be added to <%= @fullname %>
<% unless @nested -%>
# and all of its derivatives (if any).
<% end -%>
# ********************************************************************************

# For more examples see: https://origen-sdk.org/origen/guides/models/registers/

# Example of basic definition of a register at address 0x1000 with all bits R/W
# add_reg :data, 0x1000             # 32-bit by default
# add_reg :data, 0x1000, size: 16

# Example of a regular definition which defines individual bits
# reg :ctrl, 0x0024, size: 16 do |reg|
#   reg.bit 7, :coco, access: :ro
#   reg.bit 6, :aien
#   reg.bit 5, :diff
#   reg.bit 4..0, :adch, reset: 0x1F
# end
