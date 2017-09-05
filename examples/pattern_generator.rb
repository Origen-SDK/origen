# Pattern generator tests
ARGV = %w(j750.list -t debug -r approved --plugin origen_core_support)
load "origen/commands/generate.rb"
ARGV = %w(v93k_workout -t v93k -r approved --plugin none)
load "origen/commands/generate.rb"

# Pattern generator tests
ARGV = %w(j750.list -o output/j750 -t debug -r approved --plugin origen_core_support)
load "origen/commands/generate.rb"
ARGV = %W(v93k_workout -o #{Origen.root}/output/v93k -t v93k -r approved --plugin none)
load "origen/commands/generate.rb"

# Verify that name translation works
ARGV = %w(dummy_name port -t debug -r approved --plugin none)
load "origen/commands/generate.rb"

# Verify other testers
ARGV = %w(jlink.list -t jlink -r approved --plugin none)
load "origen/commands/generate.rb"
