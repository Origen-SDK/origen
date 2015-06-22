load "#{Origen.root}/target/production.rb"

$tester = Origen::Tester::V93K.new

Origen.config.mode = :debug
