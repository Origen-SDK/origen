require 'nokogiri'
require "coderay"

module CodeRay
  class << self
    alias :orig_scan :scan
    # Override the coderay scan method to remove escaped underscores prior
    # to passing over
    def scan(*args)
      args.first.gsub!("\\_", "_")
      orig_scan(*args)
    end
  end
end

class CodeblocksFilter < Nanoc::Filter
  identifier :codeblocks

  def run(content, params={})
    doc = Nokogiri::HTML.fragment(content)
    # Remove any escaped underscores from code blocks that are not marked
    # up by coderay
    doc.search('code').each do |n|
      n.content = n.content.gsub("\\_", "_")
    end
    # Same for coderay markup, not sure if this will apply always,
    # but seems to deal with highlighted Ruby
    # Keeping for future reference, but now replaced by remove underscores
    # prior to passing to coderay above
    #doc.search('.CodeRay .code').each do |n|
    #  n.xpath("//text()[. = '\\_']").each do |n|
    #    n.content = n.content.gsub("\\_", "_")
    #  end
    #  n.xpath("//text()[. = '\\']").each do |n|
    #    n.content = n.content.gsub("\\", "")
    #  end
    #end
    doc.to_html
  end

end
