# coding: utf-8
config = File.expand_path('../config', __FILE__)
require "#{config}/version"

Gem::Specification.new do |spec|
  spec.name          = "origen"
  spec.version       = Origen::VERSION
  spec.authors       = ["Stephen McGinty"]
  spec.email         = ["stephen.mcginty@freescale.com"]
  spec.summary       = %q{A Semiconductor Developer's Kit}
  #spec.homepage      = "http://"

  spec.required_ruby_version     = '>= 1.9.3'
  spec.required_rubygems_version = '>= 1.8.11'

  spec.files         = Dir["config/**/*.rb", "bin/*", "lib/**/*"
                          ]
  spec.executables   = ["origen"]
  spec.require_paths = ["lib"]

  # Don't add any logic to runtime dependencies, for example to install a specific gem
  # based on Ruby version.
  # Rubygems / Bundler do not support this and you will need to find another way around it.
  #spec.add_runtime_dependency "activesupport", "~> 4.1"
  spec.add_runtime_dependency "rake", "~>10"

  # Conditional logic in development dependencies is allowed as this is only evaluated when
  # the app is run from its own workspace
  spec.add_development_dependency "loco"
end
