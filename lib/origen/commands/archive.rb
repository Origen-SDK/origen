require 'optparse'
require 'fileutils'
require 'bundler'

options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: origen archive [options]'
end
opt_parser.parse! ARGV

Origen.log.info 'Preparing the workspace'
tmp1 = File.join(Origen.root, '..', "#{Origen.app.name}_copy")
name = "#{Origen.app.name}-#{Origen.app.version}"
tmp = File.join(Origen.root, 'tmp', name)
archive = File.join(Origen.root, 'tmp', "#{name}.origen")
FileUtils.rm_rf(tmp1) if File.exist?(tmp1)
FileUtils.rm_rf(tmp) if File.exist?(tmp)

begin
  Origen.log.info 'Creating a copy of the application'
  FileUtils.mkdir_p(tmp1)
  FileUtils.cp_r "#{Origen.root}/.", tmp1
  FileUtils.mv tmp1, tmp
ensure
  FileUtils.rm_rf(tmp1) if File.exist?(tmp1)
end

Origen.log.info 'Fetching all required gems'
Dir.chdir tmp do
  Bundler.with_clean_env do
    FileUtils.rm_rf('lbin') if File.exist?('lbin')
    FileUtils.rm_rf('.bundle') if File.exist?('.bundle')
    system 'hash -r'  # Ignore fail if not on bash
    passed = system 'bundle package --all --all-platforms --no-install'
    unless passed
      Origen.log.error 'A problem was encountered when packaging the gems, archive creation aborted!'
      exit 1
    end
  end

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
passed = system "tar -cvzf #{archive} #{tmp}"
unless passed
  Origen.log.error 'A problem was encountered creating the tarball, archive creation aborted!'
  exit 1
end

Origen.log.info 'Cleaning up'
FileUtils.rm_rf(tmp)

puts
begin
  size = `du -sh tmp/c402t_nvm_tester-2.3.0.pre1.origen`.split(/\s+/).first
  Origen.log.success "Your application archive is complete and is #{size}B in size"
rescue
  Origen.log.success 'Your application archive is complete'
end
Origen.log.success archive
