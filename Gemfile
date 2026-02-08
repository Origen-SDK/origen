source 'https://rubygems.org'

# Development dependencies
gem 'coveralls', require: false
gem "byebug", "~>11" if RUBY_VERSION < "4" # byebug C extension doesn't compile on Ruby 4.0+
#gem "stackprof", "~>0"
gem "origen_core_support", git: "https://github.com/Origen-SDK/origen_core_support.git"
#gem "origen_core_support", path: "~/Code/github/origen_core_support"
#gem "origen_doc_helpers", ">= 0.2.0"
gem "origen_doc_helpers"
gem "loco"
#gem "origen_testers", "~> 0.7"
gem 'origen_debuggers', '~> 0'
gem 'ripper-tags'
# Let Bundler resolve the best nokogiri version for the current Ruby.
# Ruby 2.6 gets ~1.13.x, Ruby 3.0+ gets latest compatible.
# gem 'nokogiri', '1.17.2' # Pinned version breaks Ruby 2.6

# Plugins that provide guide pages
gem "origen_testers", git: "https://github.com/Origen-SDK/origen_testers.git", branch: "feature/ruby_3_3_1"
gem "origen_sim", git: "https://github.com/Origen-SDK/origen_sim.git"

# Required to run the concurrent test case patterns from OrigenSim
gem 'origen_jtag'

# Pull in the latest and greatest app generator templates so that they can be
# packaged into Origen releases
gem "origen_app_generators", git: "https://github.com/Origen-SDK/origen_app_generators.git"

# Specify all runtime dependencies in origen.gemspec
gemspec
