source 'https://rubygems.org'

# Development dependencies
gem 'coveralls', require: false
gem "byebug", "~>10" #  Keep support for Ruby 2.3
#gem "stackprof", "~>0"
gem "origen_core_support", git: "https://github.com/Origen-SDK/origen_core_support.git"
#gem "origen_core_support", path: "~/Code/github/origen_core_support"
#gem "origen_doc_helpers", ">= 0.2.0"
gem "origen_doc_helpers"
gem "loco"
#gem "origen_testers", "~> 0.7"
gem 'origen_debuggers', '~> 0'
gem 'ripper-tags'
gem 'nokogiri', '1.10.10'  # Lock to this version to enable testing in Ruby 2.2

# Plugins that provide guide pages
gem "origen_testers", git: "https://github.com/Origen-SDK/origen_testers.git"
gem "origen_sim", git: "https://github.com/Origen-SDK/origen_sim.git"

# Required to run the concurrent test case patterns from OrigenSim
gem 'origen_jtag'

# Pull in the latest and greatest app generator templates so that they can be
# packaged into Origen releases
gem "origen_app_generators", git: "https://github.com/Origen-SDK/origen_app_generators.git"

# Specify all runtime dependencies in origen.gemspec
gemspec
