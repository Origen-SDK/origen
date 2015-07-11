# Interfaces must be required, can't autoload
require "c99/j750_interface"
require "c99/doc_interface"
# The majority of this class is defined in the support application,
# this is to test that the importing application can override and
# extend imported classes.
require_relative "../lib/c99/nvm"

# Dummy definition to allow Origen tests to run until the Testers plugin is available
module Testers
  class J750
  end
end
