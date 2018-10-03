load "#{Origen.root}/target/production.rb"

OrigenDebuggers::JLink.new

Origen.mode = :debug
