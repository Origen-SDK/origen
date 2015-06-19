# Compiler
def test_compile_inline_from_helper
  RGen.compile("#{RGen.root}/templates/test/inline.txt.erb", :extra => true)
end
ARGV = %w(templates/test/set1 -t debug -r approved --plugin none)
load "rgen/commands/compile.rb"

# Test that non-erb files don't compile by default
ARGV = %w(templates/test/set2/template_with_no_erb_1.txt -t debug -r approved --plugin none)
load "rgen/commands/compile.rb"

# But do compile if the config value is set
RGen.config.compile_only_dot_erb_files = false
ARGV = %w(templates/test/set2/template_with_no_erb_2.txt -t debug -r approved --plugin none)
load "rgen/commands/compile.rb"
RGen.config.compile_only_dot_erb_files = true

# Test that compile works without a tester being instantiated
RGen.config.compile_only_dot_erb_files = false
ARGV = %w(templates/test/set2/template_with_no_erb_2.txt -t no_tester -r approved --plugin none)
load "rgen/commands/compile.rb"
RGen.config.compile_only_dot_erb_files = true

# Test that block rendering works
ARGV = %w(templates/test/set3 -t debug -r approved --plugin none)
load "rgen/commands/compile.rb"

# Test that the custom inspect methods of various RGen classes work
ARGV = %w(templates/test/inspections.txt.erb -t debug -r approved --plugin none)
load "rgen/commands/compile.rb"
