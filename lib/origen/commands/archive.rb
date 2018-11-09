require 'optparse'
require 'fileutils'
require 'bundler'

options = {}
options[:exclude] = []

opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: origen archive [options]'
  opts.on('--sandbox', 'Install gems inside the archive itself so that it can run completely standalone when extracted') { options[:sandbox] = true }
  opts.on('--local', 'Install gems within your app so that it can run completely standalone, like --sandbox but no archive is created') { options[:local] = true }
  opts.on('--exclude DIR', 'Exclude the given directory from the archive, e.g. --exclude simulation') { |dir| options[:exclude] << dir }
end
opt_parser.parse! ARGV

Origen.log.info 'Preparing the workspace' unless options[:local]
tmp1 = File.join(Origen.root, '..', "#{Origen.app.name}_copy")
name = "#{Origen.app.name}-#{Origen.app.version}"
tmpdir = File.join(Origen.root, 'tmp')
tmp = File.join(tmpdir, name)
archive = File.join(Origen.root, 'tmp', "#{name}.origen")
unless options[:local]
  FileUtils.rm_rf(tmp1) if File.exist?(tmp1)
  FileUtils.rm_rf(tmp) if File.exist?(tmp)
  FileUtils.rm_rf(archive) if File.exist?(archive)
end

exclude_dirs = ['.bundle', 'output', 'tmp', 'web', 'waves', '.git', '.ref', 'dist', 'log', '.lsf', '.session'] + options[:exclude]

unless options[:local]
  begin
    Origen.log.info 'Creating a copy of the application'
    if Origen.os.linux?
      Dir.chdir Origen.root do
        cmd = "rsync -av --progress . tmp/#{name} --exclude tmp"
        exclude_dirs.each do |dir|
          cmd += " --exclude #{dir}"
        end
        passed = system cmd
        unless passed
          Origen.log.error 'A problem was encountered when creating a copy of your application, archive aborted!'
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
end

Origen.log.info 'Fetching all required gems' unless options[:local]
dir = options[:local] ? Origen.root : tmp
Dir.chdir dir do
  unless options[:local]
    Bundler.with_clean_env do
      FileUtils.rm_rf('lbin') if File.exist?('lbin')
      FileUtils.rm_rf('.bundle') if File.exist?('.bundle')
      system 'hash -r'  # Ignore fail if not on bash

      passed = system "GEM_HOME=#{File.expand_path(Origen.site_config.gem_install_dir)} bundle package --all --all-platforms --no-install"
      unless passed
        Origen.log.error 'A problem was encountered when packaging the gems, archive aborted!'
        exit 1
      end
    end
  end

  if options[:sandbox] || options[:local]
    Origen.log.info 'Installing gems into the application (this could take a while)'
    Bundler.with_clean_env do
      ENV['BUNDLE_GEMFILE'] = 'Gemfile'
      ENV['BUNDLE_PATH'] = File.join('vendor', 'gems')
      ENV['BUNDLE_BIN'] = 'lbin'
      cmd = "bundle install --gemfile #{ENV['BUNDLE_GEMFILE']} --binstubs #{ENV['BUNDLE_BIN']} --path #{ENV['BUNDLE_PATH']}"
      cmd += ' --local' unless options[:local]
      passed = system cmd
      unless passed
        Origen.log.error 'A problem was encountered installing the gem bundle, archive aborted!'
        exit 1
      end
      Origen.log.info 'Verifying the application can boot...'

      passed = system 'origen -v'
      unless passed
        Origen.log.error 'The gems have been installed locally but the application cannot boot, archive aborted!'
        exit 1
      end
    end
  end

  unless options[:local]
    Origen.log.info 'Removing all temporary and output files'
    exclude_dirs.each do |dir|
      if File.exist?(dir)
        if File.symlink?(dir)
          FileUtils.rm(dir)
        else
          FileUtils.rm_rf(dir)
        end
      end
    end
  end
end

if options[:local]
  Origen.log.success 'Gems have been successfully installed to your application'
  Origen.log.success ''
  Origen.log.success 'If you ran this in error or otherwise want to undo it, run the following command:'
  Origen.log.success '  rm -fr vendor/gems && rm -fr .bundle && origen -v && bundle'
  Origen.log.success ''
else
  Origen.log.info 'Creating archive'
  Dir.chdir tmpdir do
    passed = system "tar -cvzf #{name}.origen ./#{name}"
    unless passed
      Origen.log.error 'A problem was encountered creating the tarball, archive aborted!'
      exit 1
    end

    Origen.log.info 'Cleaning up'
    FileUtils.rm_rf(name)
  end

  puts
  begin
    size = `du -sh tmp/#{name}.origen`.split(/\s+/).first
    Origen.log.success "Your application archive is complete and is #{size}B in size"
  rescue
    Origen.log.success 'Your application archive is complete'
  end
  Origen.log.success archive
end
