require 'optparse'
require 'fileutils'
require 'bundler'

options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: origen archive [options]'
  opts.on('--sandbox', 'Install gems inside the app itself and include this in the archive)') { options[:sandbox] = true }
end
opt_parser.parse! ARGV

Origen.log.info 'Preparing the workspace'
tmp1 = File.join(Origen.root, '..', "#{Origen.app.name}_copy")
name = "#{Origen.app.name}-#{Origen.app.version}"
tmpdir = File.join(Origen.root, 'tmp')
tmp = File.join(tmpdir, name)
archive = File.join(Origen.root, 'tmp', "#{name}.origen")
FileUtils.rm_rf(tmp1) if File.exist?(tmp1)
FileUtils.rm_rf(tmp) if File.exist?(tmp)
FileUtils.rm_rf(archive) if File.exist?(archive)

begin
  Origen.log.info 'Creating a copy of the application'
  if Origen.os.linux?
    Dir.chdir Origen.root do
      cmd = "rsync -av --progress . tmp/#{name} --exclude tmp"
      ['.bundle', 'output', 'tmp', 'web', 'waves', '.git', '.ref', 'dist', 'log', '.lsf', '.session', 'simulation'].each do |dir|
        cmd += " --exclude #{dir}"
      end
      passed = system cmd
      unless passed
        Origen.log.error 'A problem was encountered when creating a copy of your application, archive creation aborted!'
        exit 1
      end
    end
  else
    FileUtils.mkdir_p(tmp1)
    FileUtils.cp_r "#{Origen.root}/.", tmp1
    FileUtils.mv tmp1, tmp
  end
ensure
  FileUtils.rm_rf(tmp1) if File.exist?(tmp1)
end

Origen.log.info 'Fetching all required gems'
Dir.chdir tmp do
  Bundler.with_clean_env do
    FileUtils.rm_rf('lbin') if File.exist?('lbin')
    FileUtils.rm_rf('.bundle') if File.exist?('.bundle')
    system 'hash -r'  # Ignore fail if not on bash

    # Path shouldn't be required with no-install, but for some reason without it it will try to install
    # to the system gem directory
    ENV['BUNDLE_PATH'] = File.expand_path(Origen.site_config.gem_install_dir)
    passed = system "bundle package --all --all-platforms --no-install --path #{ENV['BUNDLE_PATH']}"
    unless passed
      Origen.log.error 'A problem was encountered when packaging the gems, archive creation aborted!'
      exit 1
    end
  end

  if options[:sandbox]
    Bundler.with_clean_env do
      ENV['BUNDLE_GEMFILE'] = 'Gemfile'
      ENV['BUNDLE_PATH'] = File.join('vendor', 'gems')
      ENV['BUNDLE_BIN'] = 'lbin'
      cmd = "bundle install --gemfile #{ENV['BUNDLE_GEMFILE']} --binstubs #{ENV['BUNDLE_BIN']} --path #{ENV['BUNDLE_PATH']} --local"
      passed = system cmd
      unless passed
        Origen.log.error 'A problem was encountered installing the gem bundle, extraction aborted!'
        exit 1
      end
    end
  end

  exit 0

  Origen.log.info 'Removing all temporary and output files'
  ['.bundle', 'output', 'tmp', 'web', 'waves', '.git', '.ref', 'dist', 'log', '.lsf', '.session'].each do |dir|
    if File.exist?(dir)
      if File.symlink?(dir)
        FileUtils.rm(dir)
      else
        FileUtils.rm_rf(dir)
      end
    end
  end
end

Origen.log.info 'Creating archive'
Dir.chdir tmpdir do
  passed = system "tar -cvzf #{name}.origen ./#{name}"
  unless passed
    Origen.log.error 'A problem was encountered creating the tarball, archive creation aborted!'
    exit 1
  end

  Origen.log.info 'Cleaning up'
  FileUtils.rm_rf(name)
end

puts
begin
  size = `du -sh tmp/c402t_nvm_tester-2.3.0.pre1.origen`.split(/\s+/).first
  Origen.log.success "Your application archive is complete and is #{size}B in size"
rescue
  Origen.log.success 'Your application archive is complete'
end
Origen.log.success archive
