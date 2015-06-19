require 'rgen/code_generators'

# if no argument/-h/--help is passed to rgen add command, then
# it generates the help associated.
if [nil, '-h', '--help'].include?(ARGV.first)
  RGen::CodeGenerators.help 'add'
  exit
end

name = ARGV.shift

RGen::CodeGenerators.invoke name, ARGV # , behavior: :invoke, destination_root: RGen.root
