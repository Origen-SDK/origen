$VERBOSE=nil  # Don't care about world writable dir warnings and the like

require 'pathname'
if File.exist? File.expand_path("../Gemfile", Pathname.new(__FILE__).realpath)
  require 'rubygems'
  require 'bundler/setup'
else
  # If running on windows, can't use RGen helpers 'till we load it...
  if RUBY_PLATFORM == 'i386-mingw32'
    `where rgen`.split("\n").find do |match|
      match =~ /(.*)\\bin\\rgen$/
    end
    rgen_top = $1.gsub("\\", "/")
  else
    rgen_top = `which rgen`.strip.sub("/bin/rgen", "")
  end

  $LOAD_PATH.unshift "#{rgen_top}/lib"
end

require "rgen"

require "rspec/legacy_formatters"
require "#{RGen.top}/spec/format/rgen_formatter"

if RUBY_VERSION >= '2.0.0'
  require "byebug"
else
  require 'debugger'
end
require 'pry'

def load_target(target="default")
  RGen.target.switch_to target
  RGen.target.load!
end

RSpec.configure do |config|
  config.formatter = RGenFormatter
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # Enable only the newer, non-monkey-patching expect syntax.
    # For more details, see:
    #   - http://myronmars.to/n/dev-blog/2012/06/rspecs-new-expectation-syntax
    expectations.syntax = :should
  end
end
