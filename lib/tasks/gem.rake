namespace 'gem' do
  root = File.expand_path('../../..', __FILE__)

  require "#{root}/config/version"

  GEM_SPEC = "#{root}/origen.gemspec"
  GEM_NAME = "origen-#{Origen::VERSION}.gem"
  GEM_SERVER = 'http://rgen-hub.am.freescale.net:9292'

  built_gem_path = nil

  desc "Build #{GEM_NAME} into the pkg directory"
  task :build do
    sh("gem build -V '#{GEM_SPEC}'") do |_ok, _res|
      outdir = File.join(root, 'pkg')
      FileUtils.mkdir_p(outdir)
      FileUtils.mv(GEM_NAME, outdir)
      built_gem_path = File.join(outdir, GEM_NAME)
      puts "Origen #{Origen::VERSION} built to pkg/#{GEM_NAME}"
    end
  end

  desc "Push #{GEM_NAME} to Rubygems"
  task release: [:build] do
    sh("gem push #{built_gem_path}") do |ok, _res|
      if ok
        puts "Origen #{Origen::VERSION} has been released successfully"
      else
        puts 'Something went wrong!'
      end
    end
  end
end
