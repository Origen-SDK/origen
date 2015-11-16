require 'spec_helper'

describe 'Ports' do

  it 'can be connected to ports, values or register bits' do
    class Block
      include Origen::Model

      def initialize
        port :p1
        port :p2
        port :p3

        reg :reg1, 0x0, size: 8

        p1.connect_to p2[3..0], :b2_0, p3[7..6]
      end
    end

    b = Block.new

    p1.data.should == undefined
    p2.drive 0x55
    p2.drive 0xFF
    p1.data.should == 0x53
    #b.ports[:pa].is_a?(Origen::Ports::Port).should == true
    #b.ports(:pa).is_a?(Origen::Ports::Port).should == true
    #b.pa.parent.should == b
    #b.pa.size.should == 8
    #b.ports[:pa].size.should == 8
    #b.pb.size.should == 16
    #b.pa.path.should == "pa"
    #b.pb.path.should == "pb"
  end
end
