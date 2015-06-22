load "#{Origen.root}/target/production.rb"

$tester = Origen::Tester::JLink.new

Origen.config.mode = :debug
