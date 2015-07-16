# Program generator tests
ARGV = %w(program -t debug -r approved --plugin none)
load "origen/commands/program.rb"

## Verify that the testers plugin J750 is a drop-in replacement
#ARGV = %w(program -t testers750 -r approved --plugin none)
#load "origen/commands/program.rb"

# Test the Doc tester
ARGV = %w(program -t debug -r approved --doc --plugin none)
load "origen/commands/program.rb"
