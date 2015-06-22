require 'origen/code_generators'

# if no argument/-h/--help is passed to origen add command, then
# it generates the help associated.
if [nil, '-h', '--help'].include?(ARGV.first)
  Origen::CodeGenerators.help 'add'
  exit
end

name = ARGV.shift

Origen::CodeGenerators.invoke name, ARGV # , behavior: :invoke, destination_root: Origen.root
