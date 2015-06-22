load "#{Origen.root}/target/production.rb"

$tester = Origen::Tester::BDM.new

Origen.config.mode = :debug
