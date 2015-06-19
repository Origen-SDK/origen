namespace 'gem' do
  GEM_SPEC = "#{RGen.root}/#{RGen.app.name}.gemspec"
  GEM_NAME = "#{RGen.app.name}-#{RGen.app.version}.gem"
  GEM_SERVER = 'TBD'

  if File.exist?(GEM_SPEC)

    built_gem_path = nil

    desc "Build #{GEM_NAME} into the pkg directory"
    task :build do
      # Ensure all files are readable
      sh("chmod a+r -R #{RGen.root}")
      sh("gem build -V '#{GEM_SPEC}'") do |_ok, _res|
        outdir = File.join(RGen.root, 'pkg')
        FileUtils.mkdir_p(outdir)
        FileUtils.mv(GEM_NAME, outdir)
        built_gem_path = File.join(outdir, GEM_NAME)
        puts "#{RGen.app.name} #{RGen.app.version} built to pkg/#{GEM_NAME}".green
      end
    end

    desc "Push #{GEM_NAME} to the RGen gem server"
    task release: [:build] do
      sh("gem inabox --host #{GEM_SERVER} #{built_gem_path}") do |ok, _res|
        if ok
          puts "#{RGen.app.name} #{RGen.app.version} has been released successfully".green
        else
          puts 'Something went wrong!'.red
        end
      end
    end
  end
end
