require 'irb'
require 'irb/completion'

ARGV << '--help' if ARGV.empty?

aliases = {
  'i' => 'interactive',
  'f' => 'fetch'
}

@command = ARGV.shift
@command = aliases[@command] || @command

@global_commands = []
@application_options = []

# Load all of the Gemfile's dependencies and grab any global commands.
# If no Gemfile is defined, don't require any extra bundler stuff though we most likely won't register any global commands
# if Origen.site_config.user_install_enable && File.exist?(File.join(File.expand_path(Origen.site_config.origen_install_dir), 'Gemfile'))
if ENV['BUNDLE_GEMFILE']
  # Load the Gemfile
  Bundler.require
  Bundler.require(:development)
  Bundler.require(:runtime)
  Bundler.require(:default)
else
  # If we're not running from a Bundler build, which we aren't here,
  # get a list of installed system gems. Go through this list finding and get any that has a dependency
  # on Origen. If so, assume that gem is a plugin.
  # For all plugins, require it to register as a plugin.
  # The global handler below will take it from there.
  Gem::Specification.each do |gem|
    gem.dependencies.each do |d|
      if d.name == 'origen'
        require gem.name
      end
    end
  end
end

# Load the global app and an empty target, this helps to ensure that all of Origen's functionality
# is available to global commands, since many features implicitly assume the presence of an app
Origen.app
Origen.target.temporary = -> {}
Origen.load_target

# Get a list of registered plugins and get the global launcher
@global_launcher = Origen._applications_lookup[:name].dup.map do |plugin_name, plugin|
  shared = plugin.config.shared || {}
  if shared[:global_launcher]
    file = "#{plugin.root}/#{shared[:global_launcher]}"
    require file
    file
  end
end.compact

require 'origen/global_methods'
include Origen::GlobalMethods

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
  Origen.enable_debugger
else
  def debugger
    caller[0] =~ /.*\/(\w+\.rb):(\d+).*/
    puts "#{Regexp.last_match[1]}:#{Regexp.last_match[2]} - debugger statement ignored, run again with '-d' to enable it"
  end
end

case @command

when 'new', 'extract'
  require "origen/commands/#{@command}"
  exit 0

when '--version', '-v'
  require 'origen/commands/version'
  exit 0

when 'site'
  require 'origen/commands/site'
  exit 0

# when 'fetch', 'f'
#  require 'origen/commands/fetch'
#  exit 0

when 'interactive'
  IRB.start

else
  puts 'Error: Command not recognized' unless ['-h', '--help'].include?(@command)
  puts <<-EOT
Usage: origen COMMAND [ARGS]

The following commands are available:
  EOT
  cmds = <<-EOT
 new          Create a new Origen application or plugin. "origen new my_app" creates a
              new origen application workspace in "./my_app"
 interactive  Start an interactive Origen console (short-cut alias: "i"), this is just
              IRB with the 'origen' lib loaded automatically
 extract      Extract an Origen application archive (.origen file created with the archive command)
 site         Monitor and manage the Origen site configuration
  EOT
  cmds.split(/\n/).each do |line|
    puts Origen.clean_help_line(line)
  end
  puts
  if @global_launcher && !@global_launcher.empty?
    puts 'The following global commands are provided by plugins:'
    @global_commands.each do |cmds|
      cmds.split(/\n/).each do |line|
        puts Origen.clean_help_line(line)
      end
    end
    puts
  end

  puts <<-EOT
Many commands can be run with -h (or --help) for more information.

  EOT
  exit 0
end
