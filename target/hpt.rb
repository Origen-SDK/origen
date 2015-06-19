$top = C99::SOC.new
$nvm = C99::NVM.new
$tester = RGen::Tester::J750_HPT.new

$dut = $top
$soc = $top

RGen.config.mode = :debug
RGen.config.pattern_postfix = "hpt"
