# ********************************************************************************
# Any pins defined in this file will be added to <%= @fullname %>
# and all of its derivatives (if any).
# ********************************************************************************

# For more examples see: https://origen-sdk.org/origen/guides/models/pins/

# Example of how to import a pins file extracted by 'origen sim:build' and copied to your app's
# vendor/ directory (my_file_name will be the name of the file without the .rb extension)
# import 'my_file_name', dir: "#{Origen.root!}/vendor/wherever/i/like", namespace: nil

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
# add_pin_alias :new_name, :old_name
# add_pin_group_alias :new_name, :old_name
# add_pin_group_alias :data_byte0, :porta, pins: [7..0]
