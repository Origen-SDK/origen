load "#{Origen.root}/target/production.rb"

$tester = OrigenTesters::V93K.new
$tester.inline_comments = false

Origen.mode = :debug
