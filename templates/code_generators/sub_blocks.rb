# ********************************************************************************
# Any sub-blocks defined in this file be added to <%= @fullname %>
# and all of its derivatives (if any).
# ********************************************************************************

# For more examples see: https://origen-sdk.org/origen/guides/models/defining/#Adding_Sub_Blocks

# Examples
# sub_block :nvm                                      # An empty sub-block
# sub_block :nvm, base_address: 0x1000_0000           # How to define the sub-block's address
# sub_block :nvm, load_part: 'features/memory'        # Add the definitions from the given part(s)
# sub_block :nvm, load_part: ['features/memory', 'features/testable']
# sub_block :nvm, class_name: 'MyApp::NVM::Flash2K'   # Instantiate it as an instance of the given class
