require "spec_helper"

describe "Inline compiler" do

  FILE = "#{RGen.root}/templates/test/inline.txt.erb"

  class ScopeTester
    def secret
      "yo"
    end
  end

  it "basically works" do
    RGen.compile(FILE).should == "25\nHello"
  end

  it "can take options" do
    RGen.compile(FILE, extra: true).should == "25\nHello\nand goodbye"
  end

  it "can use a specific scope" do
    RGen.compile(FILE, test_scope: true, scope: ScopeTester.new).should == "25\nHello\nyo"
  end

  it "works with render" do
    RGen.compile(FILE, test_render: true).should == "25\nHello\nFrom a sub!\nx = 10"
  end
end
