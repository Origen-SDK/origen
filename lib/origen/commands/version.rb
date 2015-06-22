if Origen.app_loaded?
  puts "Application: #{Origen.app.version}"
  if Origen.config.required_origen_version && (Origen.config.required_origen_version != Origen.version)
    puts "       Origen: #{Origen.version} (App requires #{Origen.config.required_origen_version})"
  elsif Origen.config.min_required_origen_version &&
        Origen.version.less_than?(Origen.config.min_required_origen_version)
    puts "       Origen: #{Origen.version} (App requires >= #{Origen.config.min_required_origen_version})"
  elsif Origen.config.max_required_origen_version &&
        Origen.version.greater_than?(Origen.config.max_required_origen_version)
    puts "       Origen: #{Origen.version} (App requires <= #{Origen.config.max_required_origen_version})"
  else
    puts "       Origen: #{Origen.version}"
  end
else
  puts "       Origen: #{Origen.version}"
end
exit 0
