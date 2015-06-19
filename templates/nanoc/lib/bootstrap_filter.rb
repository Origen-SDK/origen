require 'nokogiri'
#require "byebug"

class BootstrapFilter < Nanoc::Filter
  identifier :bootstrap

  def run(content, params={})
    doc = Nokogiri::HTML.fragment(content)

    # Add table class to all tables so that they are formatted by bootstrap
    doc.search('table').tap{ |ns| ns.add_class('table') }.each do |n|
      n.text
    end

    # Add an anchor to all headers
    if item[:header_anchors].nil? || item[:header_anchors]
      tags = "h1, h2, h3, h4"
      first_done = false
      doc.css(tags).each do |header|
        # Skip the first header in the doc, looks better and no advantage to having an anchor on it
        if first_done
          # Don't add an anchor link to headers that already contain a link
          unless header.at_css("a")
            tag = header.name
            cls = header.attr("class")
            unless cls && cls =~ /(topic-title|topic-subtitle|no-anchor)/
              header.replace anchor(tag, header.text)
            end
          end
        end
        first_done = true
      end
    end

    doc.to_html
  end

  def anchor(tag, msg)
    id = msg.gsub(" ", "_")
    html = <<-END
<div>    
  <a class="anchor" name="#{id}"></a>          
  <#{tag}><a href="##{id}">#{msg}</a></#{tag}>          
</div>    
    END
    # Need to pass back a node, couldn't work out better syntax to do this
    Nokogiri::HTML(html).css("div")
  end
end
