# Main entry point for all RGen commands, some global option handling
# is done here (i.e. options that apply to all commands) before handing
# over to the specific command handlers
require 'optparse'

ARGV << '--help' if ARGV.empty?

RGEN_COMMAND_ALIASES = {
  'g'         => 'generate',
  'p'         => 'program',
  't'         => 'target',
  '-t'        => 'target',          # For legacy reasons
  'e'         => 'environment',
  '-e'        => 'environment',
  'mods'      => 'modifications',
  '-o'        => 'modifications',   # Legacy
  'l'         => 'lsf',
  'i'         => 'interactive',
  'c'         => 'compile',
  'pl'        => 'plugin',
  '-v'        => 'version',
  '--version' => 'version'
}

@command = ARGV.shift
@command = RGEN_COMMAND_ALIASES[@command] || @command

# Don't log to file during the save command since we need to preserve the last log,
# this is done as early in the process as possible so any deprecation warnings during
# load don't trigger a new log
RGen::Log.console_only = (%w(save target environment version).include?(@command) || ARGV.include?('--exec_remote'))

if ARGV.delete('--coverage') ||
   ((@command == 'specs' || @command == 'examples') && (ARGV.delete('-c') || ARGV.delete('--coverage')))
  require 'simplecov'
  SimpleCov.start
  RGen.log.info 'Started code coverage'
  SimpleCov.configure do
    filters.clear # This will remove the :root_filter that comes via simplecov's defaults
    add_filter do |src|
      !(src.filename =~ /^#{RGen.root}\/lib/)
    end

    # Results from commands run in succession will be merged by default
    use_merging(!ARGV.delete('--no_merge'))

    # Try and make a guess about which directory contains the bulk of the application's code
    # and create groups to match the main folders
    d1 = "#{RGen.root}/lib/#{RGen.app.name.to_s.underscore}"
    d2 = "#{RGen.root}/lib/#{RGen.app.namespace.to_s.underscore}"
    d3 = "#{RGen.root}/lib"
    if File.exist?(d1) && File.directory?(d1)
      dir = d1
    elsif File.exist?(d2) && File.directory?(d2)
      dir = d2
    else
      dir = d3
    end

    Dir.glob("#{dir}/*").each do |d|
      d = Pathname.new(d)
      if d.directory?
        add_group d.basename.to_s.camelcase, d.to_s
      end
    end

    command_name @command

    path_to_coverage_report = Pathname.new("#{RGen.root}/coverage/index.html").relative_path_from(Pathname.pwd)

    at_exit do
      SimpleCov.result.format!
      puts ''
      puts 'To view coverage report:'
      puts "  firefox #{path_to_coverage_report} &"
      puts ''
    end
  end
end

require 'rgen/global_methods'
include RGen::GlobalMethods

RGen.lsf.current_command = @command
RGen.send :current_command=, @command

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

if ARGV.include?('-verbose') || ARGV.include?('--verbose')
  options ||= {}
  RGen.log.level = :verbose
  ARGV.delete('-verbose')
  ARGV.delete('--verbose')
end

if ARGV.include?('-silent') || ARGV.include?('--silent')
  options ||= {}
  RGen.log.level = :silent
  ARGV.delete('-silent')
  ARGV.delete('--silent')
end

# If the current command is an LSF execution request (that is a request to
# execute a non-RGen command remotely)
if (@command == 'lsf' || @command == 'l') && (ARGV.include?('-e') || ARGV.include?('--execute'))
  # Don't apply these global options yet, pass them through to the underlying command
else
  if ARGV.delete('--profile')
    # This means that as well as applying to the current thread, this option will also
    # be applied to any remote jobs triggered by this thread
    RGen.app.lsf_manager.add_command_option('--profile')
    RGen.enable_profiling
  end
  if ARGV.delete('--exec_remote') && @command != 'lsf' && @command != 'l'
    RGen.running_remotely = true
  end
  # Set the RGen operating mode if supplied
  ix = ARGV.index('-m') || ARGV.index('--mode')
  if ix
    ARGV.delete_at(ix)
    mode = ARGV[ix]
    ARGV.delete_at(ix)
    RGen.app.lsf_manager.add_command_option('--mode', mode)
    RGen.mode = mode
    # Make sure this sticks for the remainder of this thread
    RGen.mode.freeze
  end
end

# Give application commands the first shot at executing the given command,
# the application file must exit upon servicing the command if it wants to
# prevent RGen from then having a go.
# This order is preferable to allowing RGen to go first since it allows
# overloading of RGen commands by the application.
if File.exist? "#{RGen.root}/config/commands.rb"
  require "#{RGen.root}/config/commands"
end

shared_commands = RGen.import_manager.command_launcher
@plugin_commands ||= []
if shared_commands && shared_commands.size != 0
  shared_commands.each do |file|
    require file
  end
end

case @command
when 'generate', 'program', 'compile', 'merge', 'interactive', 'target', 'environment',
     'ctags', 'save', 'lsf', 'web', 'time', 'dispatch', 'rc', 'lint', 'plugin' # , 'add'

  require "rgen/commands/#{@command}"
  exit 0 unless @command == 'interactive'

when 'upgrade_app'
  RGen::CodeGenerators.invoke 'bundler', [], config: { type: :application }
  RGen::CodeGenerators.invoke 'rake', []
  RGen::CodeGenerators.invoke 'r_spec', ['-f']
  exit 0

when 'upgrade_plugin'
  unless RGen.app.version.semantic?
    puts 'To upgrade to a gem your plugin must switch to semantic (1.2.3) style versioning.'
    puts
  end
  RGen::CodeGenerators.invoke 'semver', []
  RGen::CodeGenerators.invoke 'gem_setup', []
  RGen::CodeGenerators.invoke 'bundler', []
  RGen::CodeGenerators.invoke 'rake', []
  RGen::CodeGenerators.invoke 'r_spec', ['-f']
  exit 0

when 'version'
  RGen.disable_rgen_version_check do
    RGen.load_application(false)
    require 'rgen/commands/version'
  end

when 'serve'
  puts '***************************************************************'
  puts "'rgen serve' is deprecated, please use 'rgen web serve' instead"
  puts '***************************************************************'
  ARGV.unshift 'serve'
  load 'rgen/commands/web.rb'

when 'tag'
  puts '***************************************************************'
  puts "'rgen tag' is deprecated, please use 'rgen rc tag' instead"
  puts '***************************************************************'
  ARGV.unshift 'tag'
  load 'rgen/commands/rc.rb'

when 'modifications'
  puts '***************************************************************'
  puts "'rgen mods' is deprecated, please use 'rgen rc mods' instead"
  puts '***************************************************************'
  ARGV.unshift 'modifications'
  load 'rgen/commands/rc.rb'

else
  puts "Error: Command not recognized: #{@command}" unless ['-h', '--help'].include?(@command)
  puts <<-EOT
Usage: rgen COMMAND [ARGS]

The core rgen commands are:
 environment  Display or set the default environment (short-cut alias: "e")
 target       Display or set the default target (short-cut alias: "t")
 generate     Generate a test pattern (short-cut alias: "g")
 program      Generate a test program (short-cut alias: "p")
 interactive  Start an interactive RGen console (short-cut alias: "i")
 compile      Compile a template file or directory (short-cut alias: "c")
 rc           Revision control commands, see -h for details
 ctags        Generate ctags file (can be used for code navigation)
 save         Save the new or changed files from the last run or a given log file
 lsf          Monitor and manage LSF jobs (short-cut alias: "l")
 web          Web page tools, see -h for details
 time         Tools for test time analysis and forecasting
 lint         Lint and style check (and correct) your application code
 plugin       Manage RGen plugins (short-cut alias: "pl")

  EOT
  if @application_commands && !@application_commands.empty?
    puts <<-EOT
In addition to these the application has added:
#{@application_commands}
EOT
  end

  if @plugin_commands && !@plugin_commands.empty?
    puts 'The following commands are provided by plugins:'
    @plugin_commands.each do |str|
      puts str
    end
  end

  puts <<-EOT

All commands can be run with -d (or --debugger) to enable the debugger.
All commands can be run with --coverage to enable code coverage.
Many commands can be run with -h (or --help) for more information.

  EOT

  # dispatch     Dispatch an RGen command to a worker farm
  exit(1)
end
