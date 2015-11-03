require 'spec_helper'

describe 'Ports and Nets' do

  it 'ports can be accessed by name' do
    class Block
      include Origen::Model

      def initialize
        port :pa, size: 8
        port :pb, size: 16
      end
    end

    b = Block.new
    b.ports[:pa].is_a?(Origen::Ports::Port).should == true
    b.ports(:pa).is_a?(Origen::Ports::Port).should == true
    b.pa.parent.should == b
    b.pa.size.should == 8
    b.ports[:pa].size.should == 8
    b.pb.size.should == 16
    b.pa.path.should == "pa"
    b.pb.path.should == "pb"
  end

  it 'ports can be drilled down to subsets of bits' do
    class Block
      include Origen::Model

      def initialize
        port :pa, size: 8
        port :pb, size: 16 do |port|
          port.bits 7..0, :data
        end
      end
    end

    b = Block.new
    b.pb.data.size.should == 8
    b.pb.data.path.should == "pb[7:0]"
    b.pa[5].size.should == 1
    b.pa[5].path.should == "pa[5]"
    b.pa[7..4][0].path.should == "pa[4]"
    b.pa[7..4][1..0].path.should == "pa[5:4]"
  end
end
