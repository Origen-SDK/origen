load "#{Origen.root}/target/production.rb"

$tester = OrigenDebuggers::JLink.new

Origen.config.mode = :debug
