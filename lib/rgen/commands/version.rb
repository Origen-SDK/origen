if RGen.app_loaded?
  puts "Application: #{RGen.app.version}"
  if RGen.config.required_rgen_version && (RGen.config.required_rgen_version != RGen.version)
    puts "       RGen: #{RGen.version} (App requires #{RGen.config.required_rgen_version})"
  elsif RGen.config.min_required_rgen_version &&
        RGen.version.less_than?(RGen.config.min_required_rgen_version)
    puts "       RGen: #{RGen.version} (App requires >= #{RGen.config.min_required_rgen_version})"
  elsif RGen.config.max_required_rgen_version &&
        RGen.version.greater_than?(RGen.config.max_required_rgen_version)
    puts "       RGen: #{RGen.version} (App requires <= #{RGen.config.max_required_rgen_version})"
  else
    puts "       RGen: #{RGen.version}"
  end
else
  puts "       RGen: #{RGen.version}"
end
exit 0
