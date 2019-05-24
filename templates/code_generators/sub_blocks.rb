# ********************************************************************************
# Any sub-blocks defined in this file will be added to <%= @fullname %>
<% unless @nested -%>
# and all of its derivatives (if any).
<% end -%>
# ********************************************************************************

# If you want to add a nested sub-block to this block then run the following command,
# replacing my_sub_block_name with the name of your sub-block:
#   origen new block <%= Pathname.new(resource_path_to_blocks_dir(@resource_path)).relative_path_from(Origen.root) %> my_sub_block_name
#
# If instead you want to add a primary sub-block (one which supports derivatives and
# inheritance then create one using the following command and then instantiate it
# manually below:
#   origen new block my_sub_block_type/my_sub_block_name

# For more examples see: https://origen-sdk.org/origen/guides/models/defining/#Adding_Sub_Blocks

# Examples
# sub_block :nvm                                      # An empty sub-block
# sub_block :nvm, base_address: 0x1000_0000           # How to define the sub-block's address
# sub_block :nvm, load_block: 'features/memory'       # Add the definitions from the given block(s)
# sub_block :nvm, load_block: ['features/memory', 'features/testable']
# sub_block :nvm, class_name: 'MyApp::NVM::Flash2K'   # Instantiate it as an instance of the given class
