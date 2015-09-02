# Program generator tests
ARGV = %w(program -t debug -r approved --plugin none)
load "origen/commands/program.rb"

# Test the Doc tester
ARGV = %w(program -t debug -r approved --doc --plugin none)
load "origen/commands/program.rb"
