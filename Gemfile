source 'https://rubygems.org'

# Development dependencies
gem 'coveralls', require: false
gem "byebug", "~>8"  # Keep support for Ruby 2.0
#gem "stackprof", "~>0"
gem "origen_core_support", git: "https://github.com/Origen-SDK/origen_core_support.git"
#gem "origen_doc_helpers", ">= 0.2.0"
gem "origen_doc_helpers"
gem "loco"
#gem "origen_testers", "~> 0.7"
gem 'origen_debuggers', '~> 0'
gem 'ripper-tags'
gem 'nokogiri', '1.8.5'  # Lock to the version to enable testing in Ruby 2.2

# Plugins that provide guide pages
gem "origen_testers", git: "https://github.com/Origen-SDK/origen_testers.git", branch: "concurrent"
gem "origen_sim", git: "https://github.com/Origen-SDK/origen_sim.git", branch: "concurrent"

# Required to run the concurrent test case patterns from OrigenSim
gem 'origen_jtag'

# Pull in the latest and greatest app generator templates so that they can be
# packaged into Origen releases
gem "origen_app_generators", git: "https://github.com/Origen-SDK/origen_app_generators.git"

# Specify all runtime dependencies in origen.gemspec
gemspec
