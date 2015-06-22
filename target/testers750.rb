load "#{Origen.root}/target/production.rb"

$tester = Testers::J750.new

Origen.config.mode = :debug
