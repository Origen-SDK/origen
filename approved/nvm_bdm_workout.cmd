// ***************************************************************************
// This is a dummy pattern created by the RGen test environment
// ***************************************************************************
// COMMAND: (to re-generate this pattern)
//   rgen g bdm_workout -t bdm.rb
// ***************************************************************************
// ENVIRONMENT:
//   Project
//     Vault:     sync://sync-15088:15088/Projects/common_tester_blocks/rgen
//     Version:   v2.0.0.dev2.app
//     Workspace: /proj/.mem_c90tfs_testeng/r49409/C90TFS_NVM_tester/rgen_top
//   rGen
//     Vault:     sync://sync-15088:15088/Projects/common_tester_blocks/rgen
//     Version:   v2.0.0.dev2
//     Workspace: /proj/.mem_c90tfs_testeng/r49409/C90TFS_NVM_tester/rgen_top
// ***************************************************************************
// TARGET:
//   bdm.rb
// ***************************************************************************
// ######################################################################
// # Test that comments work
// ######################################################################
// Hello
// ######################################################################
// # Test that writing explicit content works
// ######################################################################
R0   // Put the part in reset
// ######################################################################
// # Test that delay works
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
// # Test write_byte
// ######################################################################
WB 0x12 0x55
// ######################################################################
// # Test write_word
// ######################################################################
WW 0x34 0xAA55
