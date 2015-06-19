require 'spec_helper'

describe Array do
  
  before :all do
    @a = (1..10).to_a
  end

  specify "duplicate methods work" do
    @a.dups?.should == false
    @a.dups.should == []
    @a.dups_with_index.should == {}
    @a[3] = 1
    @a[8] = 2
    @a[2] = 7
    @a.dups?.should == true
    @a.dups.should == [1,2,7]
    @a.dups_with_index.should == {1=>[0, 3], 2=>[1, 8], 7=>[2, 6]}
  end

end
