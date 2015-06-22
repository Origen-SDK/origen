$VERBOSE=nil  # Don't care about world writable dir warnings and the like

require 'pathname'
if File.exist? File.expand_path("../Gemfile", Pathname.new(__FILE__).realpath)
  require 'rubygems'
  require 'bundler/setup'
else
  # If running on windows, can't use Origen helpers 'till we load it...
  if RUBY_PLATFORM == 'i386-mingw32'
    `where origen`.split("\n").find do |match|
      match =~ /(.*)\\bin\\origen$/
    end
    origen_top = $1.gsub("\\", "/")
  else
    origen_top = `which origen`.strip.sub("/bin/origen", "")
  end

  $LOAD_PATH.unshift "#{origen_top}/lib"
end

require "origen"

require "rspec/legacy_formatters"
require "#{Origen.top}/spec/format/origen_formatter"

if RUBY_VERSION >= '2.0.0'
  require "byebug"
else
  require 'debugger'
end
require 'pry'

def load_target(target="default")
  Origen.target.switch_to target
  Origen.target.load!
end

RSpec.configure do |config|
  config.formatter = OrigenFormatter
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
