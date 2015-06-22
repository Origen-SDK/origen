module Origen
  env = ARGV.shift
  if env
    Origen.environment.default = env
    puts "Environment now set to: #{Origen.environment.file.basename}"
  else
    Origen.environment.describe
  end

  exit 0
end
