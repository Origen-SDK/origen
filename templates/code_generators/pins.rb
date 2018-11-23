# ********************************************************************************
# Any pins defined in this file will be added to <%= @fullname %>
# and all of its derivatives (if any).
# ********************************************************************************

# For more examples see: https://origen-sdk.org/origen/guides/models/pins/

# Examples of how to add pins
# add_pin :tck, reset: :drive_hi, meta: { max_freq: 15.Mhz }
# add_pin :tdi, direction: :input
# add_pin :tdo, direction: :output
# add_pin :tms

# Examples of how to add sized pin groups
# add_pins :porta, size: 32
# add_pins :portb, size: 16, endian: :little

# Example of how to declare ad-hoc pin groups (the pins themselves must already have been added)
# add_pin_group :jtag, :tdi, :tdo, :tck, :tms
#
# Examples of how to create pin aliases
# add_pin_alias :old_name, :new_name
# add_pin_group_alias :old_name, :new_name
# add_pin_group_alias :data_byte0, :porta, pins: [7..0]
