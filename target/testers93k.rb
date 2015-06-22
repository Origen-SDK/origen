load "#{Origen.root}/target/production.rb"

$tester = Testers::V93K.new

Origen.config.mode = :debug
