// ***************************************************************************
// GENERATED:
//   Time:    31-Aug-2015 03:21AM
//   By:      Stephen McGinty
//   Command: origen g bdm_workout -t bdm.rb
// ***************************************************************************
// ENVIRONMENT:
//   Application
//     Source:    ssh://git@github.com:Origen-SDK/origen.git
//     Version:   0.2.3
//     Branch:    master(5ccfa6bfcca) (+local edits)
//   Origen
//     Source:    https://github.com/Origen-SDK/origen
//     Version:   0.2.3
//   Plugins
//     origen_core_support:      0.1.1
//     origen_doc_helpers:       0.2.0
// ***************************************************************************
// This is a dummy pattern created by the Origen test environment
// ***************************************************************************
// ######################################################################
// ## Test that comments work
// ######################################################################
// Hello
// ######################################################################
// ## Test that writing explicit content works
// ######################################################################
R0   // Put the part in reset
// ######################################################################
// ## Test that delay works
// ######################################################################
// This should sleep for no cycles
// Wait for 0ns
// This should sleep for 1 cycle
// Wait for 100.0ms
WAIT 1
// This should sleep for 10 cycles
// Wait for 1.00s
WAIT 10
// This should sleep for 20 cycles
// Wait for 2.00s
WAIT 20
// ######################################################################
// ## Test write_byte
// ######################################################################
WB 0x12 0x55
// ######################################################################
// ## Test write_word
// ######################################################################
WW 0x34 0xAA55
