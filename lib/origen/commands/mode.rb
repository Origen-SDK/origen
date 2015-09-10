module Origen
  mode = ARGV.shift
  if mode
    Origen.mode = mode
    Origen.app.session.origen_core[:mode] = Origen.mode.to_s
    puts "Origen mode now set to: #{Origen.mode}"
  else
    puts Origen.app.session.origen_core[:mode] || 'production'
  end

  exit 0
end
