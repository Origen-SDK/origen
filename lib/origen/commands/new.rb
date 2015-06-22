require 'optparse'
require 'fileutils'
require 'httparty'
require 'digest'

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

http://origen.freescale.net/origen_app_generators

Usage: origen new [APP_NAME] [options]
END
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-v', '--version TAG', String, 'Use a specific version of Origen App Generators') { |f| options[:version] = f }
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

version = options[:version] || begin
  plugin = Origen.client.plugin(:origen_app_generators)
  plugin[:latest_version_prod]
end

version ||= '0.0.0'

version.sub!(/^v/, '')

if Origen.running_on_windows?
  tmp = 'C:/tmp/origen_app_generators'
else
  tmp = '/tmp/origen_app_generators'
end

dir = "#{tmp}/app_gen#{version}"
lib = "#{dir}/lib"
md5 = "#{tmp}/md5#{version}"

# If the app generators already exists in /tmp, check that all files are still there.
# This deals with the problem of some files being swept up by the tmp cleaner while
# leaving the top-level folder there.
if File.exist?(dir) && File.exist?(md5)
  old_sig = File.read(md5)
  hash = Digest::MD5.new
  Dir["#{dir}/**/*"].each do |f|
    hash << File.read(f) unless File.directory?(f)
  end
  new_sig = hash.hexdigest
  all_present = old_sig == new_sig
else
  all_present = false
end

unless all_present

  FileUtils.rm_rf(dir) if File.exist?(dir)
  FileUtils.mkdir_p(tmp) unless File.exist?(tmp)

  File.open("#{tmp}/app_gen#{version}.gem", 'wb') do |f|
    response =  HTTParty.get("http://origen-hub.am.freescale.net:9292/gems/origen_app_generators-#{version}.gem")
    if response.success?
      f.write response.parsed_response
    else
      puts "Sorry, could not find app generators version #{version}"
      exit 1
    end
  end

  Dir.chdir tmp do
    `gem unpack app_gen#{version}.gem`
    `rm -f app_gen#{version}.gem`
  end

  hash = Digest::MD5.new
  Dir["#{dir}/**/*"].each do |f|
    hash << File.read(f) unless File.directory?(f)
  end
  File.open(md5, 'w') { |f| f.write(hash.hexdigest) }
end

$LOAD_PATH.unshift(lib)

Origen.with_boot_environment do
  require 'origen_app_generators'
  OrigenAppGenerators.invoke(dir)
end
