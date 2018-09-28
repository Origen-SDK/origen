<% unless @dut_generator -%>
# **************************************************************************
# Any pins defined in this file will be added to ALL of your DUT targets!!!!
# **************************************************************************

<% end -%>
# For more examples see: https://origen-sdk.org/origen/guides/models/pins/

# Examples of how to add pins
# dut.add_pin :tck, reset: :drive_hi, meta: { max_freq: 15.Mhz }
# dut.add_pin :tdi, direction: :input
# dut.add_pin :tdo, direction: :output
# dut.add_pin :tms

# Examples of how to add sized pin groups
# dut.add_pins :porta, size: 32
# dut.add_pins :portb, size: 16, endian: :little

# Example of how to declare ad-hoc pin groups (the pins themselves must already have been added)
# dut.add_pin_group :jtag, :tdi, :tdo, :tck, :tms
