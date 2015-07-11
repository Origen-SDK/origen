namespace 'build' do

  desc 'Hello'
  task :test do
    puts "hello world"
  end
end

task :default => ["build:test"]
