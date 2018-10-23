require 'optparse'
require 'fileutils'
require 'bundler'

options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: origen extract FILE [options]'
end
opt_parser.parse! ARGV

archive = ARGV.first

unless File.exist?(archive)
  Origen.log.error "File not found: #{archive}"
  exit 1
end

dirname = Pathname.new(archive).basename('.origen').to_s

passed = system "tar -xvzf #{archive}"

Dir.chdir dirname do
  Bundler.with_clean_env do
    ENV['BUNDLE_GEMFILE'] = File.join(Dir.pwd, 'Gemfile')
    ENV['BUNDLE_PATH'] = File.expand_path(Origen.site_config.gem_install_dir)
    ENV['BUNDLE_BIN'] = File.join(Dir.pwd, 'lbin')
    cmd = "bundle install --gemfile #{ENV['BUNDLE_GEMFILE']} --binstubs #{ENV['BUNDLE_BIN']} --path #{ENV['BUNDLE_PATH']} --local"
    system cmd
  end
end
