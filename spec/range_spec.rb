require 'spec_helper'

describe Range do

  specify "range operations work" do
    (0..15).reverse.should == (15..0)
  end

  it "to_a works in both directions" do
    (0..3).to_a.should == [0,1,2,3]
    (3..0).to_a.should == [3,2,1,0]
  end
end
