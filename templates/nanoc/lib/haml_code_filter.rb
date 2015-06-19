# Disabled this for now, don't think anyone uses it.
# Problem is that the HAML gem seems to have changed in the upgrade to
# Ruby v2.1.0 and the below will need to be updated accordingly.
#
#require "haml"
#
## This adds a :code filter to allow code snippets to be embedded in HAML
## docs which are then highlighted by Coderay. Ruby is the default language, select
## another by including #!language in the code snippet.
##
## :code
##   def say(msg)
##     puts "#{msg}"
##   end
#module Haml::Filters::Code
#
#  include Haml::Filters::Base
#  lazy_require "coderay"
#
#  def render(content, options={})
#    ::CodeRay.scan(*prepare(content)).send(:div, {})
#  end
#
#  # Prepares the text for passing to `::CodeRay.scan`.
#  #
#  # @param [String] text
#  # @return [Array<String, Symbol>] code and language
#  def prepare(text)
#    if text =~ /#!(\S+)/
#      [ text.sub(/\A\s*#!(\S+)\s*\n+/, ""), $1.downcase.to_sym ]
#    else
#      [ text, :ruby ]
#    end
#  end
#
#  def compile(precompiler, text)
#    text = Haml::Helpers::find_and_preserve(render(text).rstrip, precompiler.options[:preserve])
#    precompiler.send(:push_text, text)
#  end
#
#end
