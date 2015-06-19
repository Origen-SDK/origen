load "#{RGen.root}/target/production.rb"

$tester = RGen::Tester::JLink.new

RGen.config.mode = :debug
