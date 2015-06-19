require 'spec_helper'

describe Range do

  specify "range operations work" do
    (0..15).reverse.should == (15..0)
  end

end
