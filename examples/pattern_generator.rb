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

# Test the --sequence option to create a concurrent pattern
ARGV = %W(#{Origen.root(:origen_sim)}/pattern/ip1_test.rb
          #{Origen.root(:origen_sim)}/pattern/ip2_test.rb
          --sequence concurrent -t origen_sim_dut -r approved --plugin origen_sim -e j750.rb)
load "origen/commands/generate.rb"

# Other concurrent pattern tests
ARGV = %w(concurrent.list -t origen_sim_dut -r approved --plugin none -e j750.rb)
load "origen/commands/generate.rb"

# Other concurrent pattern tests
ARGV = %w(concurrent_delays_with_sync.rb -t origen_sim_dut -r approved --plugin none -e v93k.rb)
load "origen/commands/generate.rb"
