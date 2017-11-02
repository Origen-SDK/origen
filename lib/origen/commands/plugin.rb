require 'optparse'
require 'fileutils'
require 'rubygems'
require 'origen/version_string'

include Origen::Utility::InputCapture

options = {}

# App options are options that the application can supply to extend this command
# app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-EOT
Usage:  origen pl
        origen pl [plugin name]
        origen pl [CMD] [options]

Quickstart Examples:
  origen pl                             # Displays the current plugin
  origen pl [plugin_name]               # Sets the specified plugin as current plugin
  origen pl reset                       # Resets the current plugin to none
  origen pl added                       # Lists the included Origen plugins
  origen pl added --all                 # Lists the included Origen plugins and external gem dependencies
  origen pl fetch [plugin_name]         # Populates plugin/gem source to a local repo (<app_root>/tmp/gems/)
  origen pl clean [plugin_name|all]     # Removes the local copy of the plugin/gem source
  origen pl info [plugin_name]          # Get additional details of the plugin

The following commands are available:

  added                               Displays all plugins that are currently included in this app locally
  reset                               Resets the current plugin to none
  fetch                               Populates plugin/gem source to a local repo (<app_root>/tmp/gems/)
  clean                               Removes the local copy of the plugin/gem source
  info                                Displays detailed information about the plugin/gem

The following options are available:
  EOT
  opts.on('-a', '--allr', 'List all plugins/gems (including external)') {  options[:debugger] = true }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV

QUIET_ATTRS = %w(
  files test_files signing_key licenses rdoc_options
  autorequire cert_chain post_install_message
)

def self._local_gems
  gems = {}
  Gem::Specification.sort_by { |g| [g.name.downcase, g.version] }.group_by(&:name).map do |name, specs|
    gems[name.to_sym] = {
      name:     name,
      version:  specs.map(&:version).join(','),
      location: specs.map(&:full_gem_path).join(','),
      authors:  specs.map(&:authors).join(',')
    }
  end
  gems
end

def self._local_gems_orig
  Gem::Specification.sort_by { |g| [g.name.downcase, g.version] }.group_by(&:name)
end

def self._session_gem_path
  "#{Origen.app.root}/tmp/gems"
end

def self._application_gemfile
  "#{Origen.app.root}/Gemfile"
end

def self._local_path_to_gem(gem)
  "#{_session_gem_path}/#{Pathname(gem[:location]).basename}"
end

def self._gem_basename(gem)
  "#{Pathname(gem[:location]).basename}"
end

def self._gem_rc_version(gem)
  gem[:version]
end

def self._update_gemfile
  content = File.read(_application_gemfile)

  search_regexp = "# ORIGEN PLUGIN AUTO-GENERATED.*# /ORIGEN PLUGIN AUTO-GENERATED.*?\n"

  if Origen.app.session.gems.keys.empty?
    new_contents = content.gsub(/#{search_regexp}/m, '')
  else
    replacement_string = "# ORIGEN PLUGIN AUTO-GENERATED---------------DO NOT REMOVE THIS LINE-------------\n"
    replacement_string += "# -- DO NOT CHECK IN WITH THIS SECTION!\n"
    replacement_string += "# -- DO NOT HAND MODIFY!\n"
    replacement_string += "# -- USE 'origen pl clean all' to reset\n"
    replacement_string += "\n"

    Origen.app.session.gems.keys.sort.each do |g|
      replacement_string += "gem '#{g}', path: '#{Origen.app.session.gems[g.to_sym]}'\n"
      replacement_string += "puts \"\\e[1;93;40mWARNING: Using session gem for '#{g}'\\e[0m\"\n"
    end

    replacement_string += "def gem(*args)\n"
    replacement_string += "  return if [#{Origen.app.session.gems.keys.sort.map { |e| "'" + e.to_s + "'" }.join(',')}].include? args[0]\n"
    replacement_string += "  super(*args)\n"
    replacement_string += "end\n"
    replacement_string += "#\n"
    replacement_string += "# /ORIGEN PLUGIN AUTO-GENERATED---------------DO NOT REMOVE THIS LINE------------\n"

    if content =~ /#{search_regexp}/m
      new_contents = content.gsub(/#{search_regexp}/m, replacement_string)
    else
      new_contents = replacement_string + content
    end
  end
  File.open(_application_gemfile, 'w') { |file| file.puts new_contents }
end

gems = _local_gems

if !ARGV[0]
  if Origen.app.plugins.current
    puts "Current plugin is: #{Origen.app.plugins.current.name}"
  else
    puts <<-EOT
No plugin set!

To work with an included plugin, set it as current plugin using the following command:
    origen pl <plugin-name>
    EOT
  end
else
  case input = ARGV.shift
  when 'reset', 'none'
    Origen.app.plugins.current = nil
    puts 'Successfully cleared the default plugin!'
  # when 'add'
  #  plugin_name = ARGV.shift
  #  version = ARGV.shift
  #  if plugin_name && version
  #    Origen.plugins_manager.add(plugin_name, version, options)
  #  else
  #    puts 'Zero or less arguments provided!'
  #  end
  when 'added'
    puts 'The following plugins are included in this app:'
    puts
    format = "%30s\t%30s\t%30s\n"
    printf(format, 'Origen_Name', 'Name', 'Version')
    printf(format, '---------', '----', '-------')

    Origen.app.plugins.sort_by { |p| p.name.to_s }.each do |plugin|
      printf(format, plugin.name, plugin.config.name, plugin.version)
    end
    puts
    exit 0
  when 'fetch'
    gem = ARGV[0]
    if gem
      if gems.key?(gem.to_sym)
        # Initialize ./tmp/gems/
        FileUtils.mkdir_p(_session_gem_path) unless Dir.exist? _session_gem_path

        if Dir.exist? _local_path_to_gem(gems[gem.to_sym])
          # check if already exists, ask for permission to blow away
          puts ''
          puts "Plugin/Gem '#{_gem_basename(gems[gem.to_sym])}' already exists locally, would you like to replace?"
          puts "(This will delete and replace the exising copy at #{_local_path_to_gem(gems[gem.to_sym])})"
          puts ''
          get_text confirm: true
          Origen::Log.console_only do
            Dir.chdir Origen.root do
              # Blow away these temporary files
              system("rm -fr #{_local_path_to_gem(gems[gem.to_sym])}")
            end
          end
        end

        if Origen.has_plugin?(gem)
          # Set up the requested plugin workspace
          rc_url = Origen.app(gem.to_sym).config.rc_url || Origen.app(gem.to_sym).config.vault
          if rc_url =~ /git/
            Origen::RevisionControl::Git.git("clone #{rc_url} #{_gem_basename(gems[gem.to_sym])}", local: _session_gem_path, verbose: true)
          else
            # Use Origen::RevisionControl for DesignSync
            rc = Origen::RevisionControl.new remote: rc_url, local: _local_path_to_gem(gems[gem.to_sym])
            tag = Origen::VersionString.new(_gem_rc_version(gems[gem.to_sym]))
            tag = tag.prefixed if tag.semantic?
            rc.build version: tag
          end
        else
          puts 'Not an Origen plugin, only COPYING source.'
          FileUtils.cp_r(gems[gem.to_sym][:location], _session_gem_path)
        end

        # FileUtils.cp_r(gems[gem.to_sym][:location], _session_gem_path)
        unless options[:dont_use]
          Origen.app.session.gems[gem.to_sym] = "#{_local_path_to_gem(gems[gem.to_sym])}"
        end

        _update_gemfile

        puts "Fetched #{gem} to tmp/gems/#{_gem_basename(gems[gem.to_sym])}"
        puts ''
      else
        puts "Error: '#{gem}' is not a currently used plugin/gem.  Use 'origen pl list' for gem list."
      end
    else
      puts "Error: Must specify plugin/gem to be fetched. Use 'origen pl -h' for usage"
    end
  when 'clean'
    gem = ARGV[0]
    if gem
      if gem == 'all'
        if Dir.exist? _session_gem_path
          puts ''
          puts 'You are about to delete all local plugin/gems (tmp/gems/).  IS THAT CORRECT?'
          puts ''
          get_text confirm: true
          Origen::Log.console_only do
            Dir.chdir Origen.root do
              system("rm -fr #{_session_gem_path}")
            end
          end
          unless Origen.app.session.gems.keys.empty?
            Origen.app.session.gems.keys.sort.each do |g|
              Origen.app.session.gems.delete_key(g)
            end
            _update_gemfile
          end
        else
          puts 'There are no local plugins/gems present, nothing to clean.'
        end
      elsif gems.key?(gem.to_sym)
        if Dir.exist? _local_path_to_gem(gems[gem.to_sym])
          # check if already exists, ask for permission to blow away
          puts ''
          puts "You are about to delete the local copy of '#{gem}' (tmp/gems/#{_gem_basename(gems[gem.to_sym])}).  IS THAT CORRECT?"
          puts ''
          get_text confirm: true
          Origen::Log.console_only do
            Dir.chdir Origen.root do
              system("rm -fr #{_local_path_to_gem(gems[gem.to_sym])}")
            end
          end
          Origen.app.session.gems.delete_key(gem.to_sym)
          _update_gemfile
        else
          puts "Plugin/Gem '#{gem}' is not locally present, nothing to clean."
        end
      end
    else
      puts "Error: Must specify plugin/gem to be cleaned or 'all'. Use 'origen pl -h' for usage"
    end
  when 'info'
    gem = ARGV[0]
    if gem
      if gems.key?(gem.to_sym)
        a = _local_gems_orig[gem].to_yaml.split(/\n+/)
        skip = true

        if options[:gem_location] || options[:gem_version]
          puts '================================================================================='
          puts "Gem Name: #{gems[gem.to_sym][:name]}"
          puts "Version:  #{gems[gem.to_sym][:version]}" if options[:gem_version]
          puts "Location: #{gems[gem.to_sym][:location]}" if options[:gem_location]
          puts '================================================================================='
        else
          puts '================================================================================='
          puts "Gem Name: #{gems[gem.to_sym][:name]}"
          puts "Version:  #{gems[gem.to_sym][:version]}"
          puts "Location: #{gems[gem.to_sym][:location]}"
          puts '---------------------------------------------------------------------------------'
          puts 'Details:'
          a.each do |line|
            if line =~ /^  (\w+):(.*)$/
              topic = Regexp.last_match(1)
              if QUIET_ATTRS.include? topic
                skip = true
              else
                skip = false
              end
            end
            puts "  #{line}" unless skip
          end
          puts '---------------------------------------------------------------------------------'
          puts '================================================================================='
        end
      else
        puts "Error: '#{gem}' not a valid command or plugin/gem. Use 'origen pl -h' for usage or 'origen pl list' for plugin/gem list."
      end
    else
      puts "Error: Must specify plugin/gem for the info command. Use 'origen pl -h' for usage"
    end
  when 'list'
    longest_key = gems.keys.max_by(&:length)
    puts ''
    printf "%-#{longest_key.length}s %-15s %s\n", 'Gem', 'Version', 'Location'
    puts '--------------------------------------------------------------------------------------------------------------'
    gems.each do |k, v|
      printf "%-#{longest_key.length}s %-15s %s\n", k, v[:version], v[:location]
    end
    puts ''
  #  Origen.plugins_manager.list
  # when 'describe'
  #  puts Origen.plugins_manager.describe(ARGV.shift)
  # when 'remove'
  #  plugin_name = ARGV.shift
  #  if plugin_name
  #    Origen.plugins_manager.remove(plugin_name)
  #  else
  #    puts 'No plugin name provided!'
  #  end
  # when 'update'
  #  plugin_name = ARGV.shift
  #  version = ARGV.shift
  #  if plugin_name && version
  #    Origen.plugins_manager.update(plugin_name, version)
  #  else
  #    puts 'Zero or less arguments provided!'
  #  end

  else
    Origen.app.plugins.current = input.to_sym
    if Origen.app.plugins.current
      puts "#{Origen.app.plugins.current.name} is now set as the current plugin."
    else
      puts "#{input} is not among this application's plugins, the current plugin is currently cleared!"
    end
  end

end
