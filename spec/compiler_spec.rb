require "spec_helper"

describe "Inline compiler" do

  FILE = "#{Origen.root}/templates/test/inline.txt.erb"
  FILE2 = "#{Origen.root}/templates/test/inline_with_layout.txt.erb"

  class ScopeTester
    def secret
      "yo"
    end

    def layout
      "#{Origen.root}/templates/test/layout.txt.erb"
    end
  end

  it "basically works" do
    Origen.compile(FILE).should == "25\nHello"
  end

  it "can take options" do
    Origen.compile(FILE, extra: true).should == "25\nHello\nand goodbye"
  end

  it "can use a specific scope" do
    Origen.compile(FILE, test_scope: true, scope: ScopeTester.new).should == "25\nHello\nyo"
  end

  it "works with render" do
    Origen.compile(FILE, test_render: true).should == "25\nHello\nFrom a sub!\nx = 10"
  end

  it "layout works from a scope" do
    Origen.compile(FILE2, scope: ScopeTester.new).should == "Layout header\nyo\nLayout footer"
  end

  it "layout works from a scope on a string template" do
    template =<<-END
% render layout do
<%= secret %>
% end
    END
    Origen.compile(template, scope: ScopeTester.new, string: true).should == "Layout header\nyo\nLayout footer"
  end
end
