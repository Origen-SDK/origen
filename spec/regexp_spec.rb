require 'spec_helper'

describe Regexp do
  
  before :all do
    @a = /abc/i
  end

  specify "regular expressions can be converted to a string" do
    @a.to_txt.should == "\/abc\/i"
    @a.to_txt(no_mods: true).should == "\/abc\/"
  end

end
