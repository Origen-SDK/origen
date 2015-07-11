namespace 'build' do

  desc 'Hello'
  task :test do
    puts "hello"
  end

end

task :default => ["build:test"]
