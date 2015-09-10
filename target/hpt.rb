$top = C99::SOC.new
$nvm = C99::NVM.new
$tester = OrigenTesters::J750_HPT.new

$dut = $top
$soc = $top

Origen.mode = :debug
Origen.config.pattern_postfix = "hpt"
