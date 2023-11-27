require 'optparse'
require 'fileutils'
require 'httparty'
require 'digest'
require 'gems'
require 'time'

include Origen::Utility::InputCapture

options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = <<-END
Generate a new Origen application.

This runs the Origen App Generators plugin to generate the new application, this provides many
engineering domain specific application shells as well as a generic application shell.

By default this will always run the latest and greatest production release of the application
generators regardless of the base Origen version that this command is being launched from.

See the website for more details:

https://origen-sdk.org/origen_app_generators

Usage: origen new [APP_NAME] [options]
END
  opts.on('-d', '--debugger', 'Enable the debugger') { options[:debugger] = true }
  opts.on('-f', '--fetch', 'Fetch the latest versions of the app generators, otherwise happens every 24hrs') { options[:fetch] = true }
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.orig_parse! ARGV
options[:patterns] = ARGV

dir = ARGV.first

unless dir
  puts 'You must supply a path to the workspace you wish to create'
  exit 1
end

unless Dir["#{dir}/*"].empty?
  puts 'The requested workspace is not empty, please delete it and try again, or select a different path.'
  exit 1
end

generators_dir = "#{Origen.home}/app_generators"
update_required = false

# Update the generators every 24hrs unless specifically requested
if options[:fetch] || !File.exist?(generators_dir)
  update_required = true
else
  if Origen.session.app_generators[generators_dir]
    if Time.now - Origen.session.app_generators[generators_dir] > 60 * 60 * 24
      update_required = true
    end
  else
    update_required = true
  end
end

generators = [['https://rubygems.org', 'origen_app_generators']] + Array(Origen.site_config.app_generators)

def use_packaged_generators
  puts "Using origen_app_generators that was packaged with Origen #{Origen.version}"
  FileUtils.cp_r Origen.top.join('origen_app_generators').to_s, '.'
  FileUtils.mv 'origen_app_generators', '0'
end

if update_required
  FileUtils.rm_rf(generators_dir) if File.exist?(generators_dir)
  FileUtils.mkdir_p(generators_dir)

  Dir.chdir generators_dir do
    generators.each_with_index do |gen, i|
      # If a reference to a gem from a gem server
      if gen.is_a?(Array)
        begin
          print "Determining the latest version of #{gen[1]}..."
          response = HTTParty.get("#{gen[0]}/api/v1/dependencies.json?gems=#{gen[1]}", timeout: 2)

          if response.success?
            latest_version = JSON.parse(response.body).map { |v| v['number'] }.max
            puts latest_version.to_s

            url = "#{gen[0]}/gems/#{gen[1]}-#{latest_version}.gem"
            print "Fetching #{url}..."
            response = HTTParty.get(url, timeout: 5)
            if response.success?
              puts 'SUCCESS'
              File.open("#{gen[1]}-#{latest_version}.gem", 'wb') do |f|
                f.write response.parsed_response
              end

              `gem unpack #{gen[1]}-#{latest_version}.gem`
              FileUtils.rm_rf("#{gen[1]}-#{latest_version}.gem")
              FileUtils.mv("#{gen[1]}-#{latest_version}", i.to_s)
            else
              puts 'FAILED'
              use_packaged_generators if i == 0
            end
          else
            puts 'FAILED'
            use_packaged_generators if i == 0
          end
        rescue
          puts 'FAILED'
          use_packaged_generators if i == 0
        end

      # If a reference to a git repo
      elsif gen.to_s =~ /\.git$/
        begin
          print "Fetching #{gen}..."
          Origen::RevisionControl.new(remote: gen, local: i.to_s).checkout(version: 'master', force: true)
          puts 'SUCCESS'
        rescue
          puts 'FAILED'
        end

      # Assume a reference to a folder
      else
        begin
          FileUtils.cp_r(gen, i.to_s) if File.exist?(gen)
          puts 'SUCCESS'
        rescue
          puts 'FAILED'
        end
      end
    end

    Origen.session.app_generators[generators_dir] = Time.now
  end
else
  puts 'Using cached app generators, run again with -f if you want to force a refresh'
end
puts

generators.each_with_index do |gen, i|
  lib = "#{generators_dir}/#{i}/lib"
  $LOAD_PATH.unshift(lib)
end

Origen.with_boot_environment do
  require 'origen_app_generators'
  generators.each_with_index do |gen, i|
    loader = "#{generators_dir}/#{i}/config/load_generators.rb"
    require loader if File.exist?(loader)
  end
  OrigenAppGenerators.invoke(dir)
end
