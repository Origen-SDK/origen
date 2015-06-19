module RGen
  env = ARGV.shift
  if env
    RGen.environment.default = env
    puts "Environment now set to: #{RGen.environment.file.basename}"
  else
    RGen.environment.describe
  end

  exit 0
end
