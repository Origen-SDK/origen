require 'optparse'
require 'fileutils'
require 'rubygems'

include Origen::Utility::InputCapture

options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = <<-END
Usage: origen gem
       origen gem gem_name [option]
       origen gem fetch gem_name 
       origen gem clean (gem_name|all)

Quickstart Examples:
  origen gem                           # Displays the list of currently used gems
  origen gem gem_name                  # Displays details of specified gem
  origen gem fetch gem name            # Copies gem source to a local repo (<application_top_level_path>/tmp/gems)
  origen gem clean (gem_name|all)      # Removes/deletes the local copy of the gem source

The following options are available:
  END
  opts.on('--location', 'Display the location of the specified gem'){ options[:gem_location] = true }
  opts.on('--version', 'Display the version of the specified gem'){ options[:gem_version] = true }
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV

QUIET_ATTRS = %w(
  files test_files signing_key licenses rdoc_options
  autorequire cert_chain post_install_message
)


def self._local_gems
  gems = {}
  Gem::Specification.sort_by{ |g| [g.name.downcase, g.version] }.group_by{ |g| g.name }.map{ |name, specs|
    gems[name.to_sym] = { 
      name: name,
      version: specs.map{ |spec| spec.version }.join(','), 
      location: specs.map{ |spec| spec.full_gem_path }.join(','),
      authors: specs.map{ |spec| spec.authors }.join(',')
    }
  }
  gems
end

def self._local_gems_orig
  Gem::Specification.sort_by{ |g| [g.name.downcase, g.version] }.group_by{ |g| g.name }
end

def self._session_gem_path
  "#{Origen.app.root}/tmp/gems"
end

def self._local_path_to_gem(gem)
  "#{_session_gem_path}/#{Pathname(gem[:location]).basename}"
end

def self._gem_basename(gem)
  "#{Pathname(gem[:location]).basename}"
end

gems = _local_gems
#puts _session_gem_path

if !ARGV[0]
  longest_key = gems.keys.max_by(&:length)

  puts ''
  printf "%-#{longest_key.length}s %-15s %s\n", 'Gem', 'Version', 'Location'
  puts "--------------------------------------------------------------------------------------------------------------"
  gems.each do |k,v|
    printf "%-#{longest_key.length}s %-15s %s\n", k, v[:version], v[:location]
  end
  puts ''
else
  case input = ARGV.shift
  when 'clean'
    gem = ARGV[0]
    if gem
      if gem == 'all'
        if Dir.exists? _session_gem_path
          puts ''
          puts "You are about to delete all local gems (tmp/gems/).  IS THAT CORRECT?"
          puts ''
          get_text confirm: true  
          Origen::Log.console_only do
            Dir.chdir Origen.root do
              system("rm -fr #{_session_gem_path}")
            end
          end
        else
          puts "There are no local gems present, nothing to clean."
        end
      elsif gems.key?(gem.to_sym)
        if Dir.exists? _local_path_to_gem(gems[gem.to_sym])
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
        else
          puts "Gem '#{gem}' is not locally present, nothing to clean."
        end
      end
    else
      puts "Error: Must specify gem to be cleaned or 'all'. Use 'origen gem -h' for usage"
      puts opts
    end
  when 'fetch'
    gem = ARGV[0]
    if gem
      if gems.key?(gem.to_sym)
        # Initialize ./tmp/gems/
        FileUtils.mkdir(_session_gem_path) unless Dir.exists? _session_gem_path
        
        if Dir.exists? _local_path_to_gem(gems[gem.to_sym])
          # check if already exists, ask for permission to blow away
          puts ''
          puts "Gem '#{_gem_basename(gems[gem.to_sym])}' already exists locally, would you like to replace?"
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

        FileUtils.cp_r(gems[gem.to_sym][:location], _session_gem_path)
        # unless options[:dont_use]
        #   # point to local copy and save as session
        # end
      else
        puts "Error: '#{gem}' is not a currently used gem.  Use 'origen gem' for gem list."
      end
      puts "Fetched #{gem} to tmp/gems/#{_gem_basename(gems[gem.to_sym])}"
    else
      puts "Error: Must specify gem to be fetched. Use 'origen gem -h' for usage"
    end
  # when 'reset'
  #   gem = ARGV[0]
  #   if gem
  #     puts "Resetting #{gem} to Gemfile/gemspec"
  #   else
  #     puts "Error: Must specify gem to be cleaned or 'all'"
  #   end
  else
    gem = input
    if gems.key?(gem.to_sym)
      a = _local_gems_orig[gem].to_yaml.split(/\n+/)
      skip = true

      if options[:gem_location] || options[:gem_version]
        puts "================================================================================="
        puts "Gem Name: #{gems[gem.to_sym][:name]}"
        puts "Version:  #{gems[gem.to_sym][:version]}" if options[:gem_version]
        puts "Location: #{gems[gem.to_sym][:location]}" if options[:gem_location]
        puts "================================================================================="
      else
        puts "================================================================================="
        puts "Gem Name: #{gems[gem.to_sym][:name]}"
        puts "Version:  #{gems[gem.to_sym][:version]}"
        puts "Location: #{gems[gem.to_sym][:location]}"
        puts "---------------------------------------------------------------------------------"
        puts "Details:"
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
        puts "---------------------------------------------------------------------------------"
        puts "================================================================================="
      end
    else
      puts "Error: '#{gem}' not a valid command or gem. Use 'origen gem -h' for usage or 'origen gem' for gem list."
    end
  end
end
