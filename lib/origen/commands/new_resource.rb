# require 'optparse'
# require 'origen/commands/helpers'
#
# options = {}
#
## App options are options that the application can supply to extend this command
# app_options = @application_options || []
# opt_parser = OptionParser.new do |opts|
#  opts.banner = 'Usage: origen new RESOURCE_TYPE RESOURCE_NAME [options]'
#  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
#  # Apply any application option extensions to the OptionParser
#  Origen::CommandHelpers.extend_options(opts, app_options, options)
#  opts.separator ''
#  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
# end
#
# opt_parser.parse! ARGV
#
# command = ARGV.shift
#
# case command
# when "model"
#
#
# else
#  puts "Unknown resource type, must be one of: model"
#  exit 1
# end

require 'origen/code_generators'

# if no argument/-h/--help is passed to origen add command, then
# it generates the help associated.
if [nil, '-h', '--help'].include?(ARGV.first)
  Origen::CodeGenerators.help 'new'
  exit
end

name = ARGV.shift

Origen::CodeGenerators.invoke name, ARGV # , behavior: :invoke, destination_root: Origen.root
