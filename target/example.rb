# The target file is run before *every* pattern and at a minimum must instantiate
# a tester model and a top level object for you to interact with from the pattern
# sources.
#
# Naming is arbitrary but instances names should be prefixed with $ which indicates a 
# global variable in Ruby, and this is required in order for the objects instantiated
# here to be visible at pattern source level (and anywhere else you want to refer 
# to them).
#
# The target file is also an opportunity to apply any global configuration prior 
# to running the pattern - i.e. this file is run before every pattern is executed
# and is an opportunity to establish state.

$tester = Origen::Tester::J750.new  # Set the tester to the Origen J750 model
$dut    = Pioneer.new             # Instantiate an SoC instance

# Production mode will require that there are no modified files in the workspace
# and anything else that you conditionally add to your project files.
# Production mode is enabled by default, disable it like this...
Origen.config.mode = :debug

# Add any taget specific setup here. i.e. you can call any methods on these top level
# objects here to configure them. 
# For pattern specific configuration do it in the individual pattern source, for 
# global configuration do it here. e.g.
# $dut.do_something_before_every_pattern
