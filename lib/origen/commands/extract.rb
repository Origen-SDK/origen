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

if File.exist?(dirname)
  Origen.log.error "The application directory already exists (#{dirname}), delete it and then try again if you want to overwrite it"
  exit 1
end

passed = system "tar -xvzf #{archive}"
unless passed
  Origen.log.error 'A problem was encountered extracting the tarball, extraction aborted!'
  exit 1
end

Dir.chdir dirname do
  Bundler.with_clean_env do
    ENV['BUNDLE_GEMFILE'] = File.join(Dir.pwd, 'Gemfile')
    vendor_gems = File.join(Dir.pwd, 'vendor', 'gems_sandbox')
    if File.exist?(vendor_gems)
      ENV['BUNDLE_PATH'] = vendor_gems
    else
      ENV['BUNDLE_PATH'] = File.expand_path(Origen.site_config.gem_install_dir)
    end
    ENV['BUNDLE_BIN'] = File.join(Dir.pwd, 'lbin')
    cmd = "bundle install --gemfile #{ENV['BUNDLE_GEMFILE']} --binstubs #{ENV['BUNDLE_BIN']} --path #{ENV['BUNDLE_PATH']} --local"
    passed = system cmd
    unless passed
      Origen.log.error 'A problem was encountered installing the gem bundle, extraction aborted!'
      exit 1
    end

    Origen.log.info 'Trying to boot the application...'

    passed = system 'origen -v'
    if passed
      Origen.log.success 'Your application has been extracted and can boot up'
    else
      Origen.log.error 'Something went wrong at the final hurdle, your application has been extracted but cannot boot'
    end
  end
end
