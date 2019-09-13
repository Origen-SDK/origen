namespace 'gem' do
  GEM_SPEC = "#{Origen.root}/#{Origen.app.gem_name}.gemspec"
  GEM_NAME = "#{Origen.app.gem_name}-#{Origen.app.version}.gem"

  if File.exist?(GEM_SPEC)

    built_gem_path = nil

    desc "Build #{GEM_NAME} into the pkg directory"
    task :build do
      # Ensure all files are readable
      sh("chmod a+r -R #{Origen.root}")
      sh("gem build -V '#{GEM_SPEC}'") do |_ok, _res|
        outdir = File.join(Origen.root, 'pkg')
        FileUtils.mkdir_p(outdir)
        FileUtils.mv(GEM_NAME, outdir)
        built_gem_path = File.join(outdir, GEM_NAME)
        puts "#{Origen.app.name} #{Origen.app.version} built to pkg/#{GEM_NAME}".green
      end
    end

    desc "Push #{GEM_NAME} to the Origen gem server"
    task release: [:build] do
      if Origen.app.config.release_externally
        cmd = "gem push #{built_gem_path}"
      else
        url = Origen.site_config.gem_server_push || Origen.site_config.gem_server!
        if Origen.site_config.gem_push_cmd
          cmd = Origen.site_config.gem_push_cmd.gsub('+URL+', url).gsub('+GEM+', built_gem_path)
        else
          cmd = "gem push #{built_gem_path} --host #{url}"
        end
      end
      sh(cmd) do |ok, _res|
        if ok
          puts "#{Origen.app.name} #{Origen.app.version} has been released successfully".green
        else
          puts "Something went wrong releasing #{Origen.app.name} to the gem server!".red
        end
      end
    end
  end
end
