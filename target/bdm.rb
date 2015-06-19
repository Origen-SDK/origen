load "#{RGen.root}/target/production.rb"

$tester = RGen::Tester::BDM.new

RGen.config.mode = :debug
