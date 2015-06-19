require 'irb'
require 'irb/completion'

ARGV << '--help' if ARGV.empty?

aliases = {
  'i' => 'interactive',
  'f' => 'fetch'
}

command = ARGV.shift
command = aliases[command] || command

require 'rgen/global_methods'
include RGen::GlobalMethods

if ARGV.delete('-d') || ARGV.delete('--debug')
  begin
    if RUBY_VERSION >= '2.0.0'
      require 'byebug'
    else
      require 'rubygems'
      require 'ruby-debug'
    end
  rescue LoadError
    def debugger
      caller[0] =~ /.*\/(\w+\.rb):(\d+).*/
      puts 'The debugger gem is not installed, add the following to your Gemfile:'
      puts
      puts "if RUBY_VERSION >= '2.0.0'"
      puts "  gem 'byebug', '~>3.5'"
      puts 'else'
      puts "  gem 'debugger', '~>1.6'"
      puts 'end'
      puts
    end
  end
  RGen.enable_debugger
else
  def debugger
    caller[0] =~ /.*\/(\w+\.rb):(\d+).*/
    puts "#{Regexp.last_match[1]}:#{Regexp.last_match[2]} - debugger statement ignored, run again with '-d' to enable it"
  end
end

case command

when 'new'
  require 'rgen/commands/new'

when '--version', '-v'
  require 'rgen/commands/version'

when 'fetch', 'f'
  require 'rgen/commands/fetch'

when 'interactive'
  IRB.start

else
  puts 'Error: Command not recognized' unless ['-h', '--help'].include?(command)
  puts <<-EOT
Usage: rgen COMMAND [ARGS]

The following commands are available:
 new          Create a new RGen application or plugin. "rgen new my_app" creates a
              new rgen application workspace in "./my_app"
 interactive  Start an interactive RGen console (short-cut alias: "i"), this is just
              IRB with the 'rgen' lib loaded automatically
 fetch        Automatically creates the workspace for the requested plugin and
              populates the latest version of the plugin (short-cut alias: "f")

Many commands can be run with -h (or --help) for more information.
  EOT
  exit(1)
end
