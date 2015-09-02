# Interfaces must be required, can't autoload
require "c99/ate_interface"
require "c99/doc_interface"
# The majority of this class is defined in the support application,
# this is to test that the importing application can override and
# extend imported classes.
require_relative "../lib/c99/nvm"
