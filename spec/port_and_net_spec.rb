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
          port.bits 7..0, :d1
        end
      end
    end

    b = Block.new
    b.pb.d1.size.should == 8
    b.pb.d1.path.should == "pb[7:0]"
    b.pb.d1[3..2].path.should == "pb[3:2]"
    b.pa[5].size.should == 1
    b.pa[5].path.should == "pa[5]"
    b.pa[7..4][0].path.should == "pa[4]"
    b.pa[7..4][1..0].path.should == "pa[5:4]"
  end

  it 'ports can be tied off to a value' do
    class Block
      include Origen::Model
      def initialize
        port :pa, size: 8
      end
    end

    b = Block.new
    b.pa.netlist_top_level.should == b
    b.pa.connect_to(0)
    b.pa.data.should == 0
    b.pa[4].data.should == 0
    b.pa[3..0].data.should == 0
    
    b = Block.new
    b.pa.connect_to(0x5A)
    b.pa.data.should == 0x5A
    n = b.pa[3..0]
    n.data.should == 0xA
    b.pa[7..4].data.should == 0x5
  end

  it 'vectors are considered identical if they have the same attributes' do
    V = Origen::Netlist::Vector
    v1 = V.new("sub1.x", nil, 0)
    v2 = V.new("sub1.x", nil, 0)
    v3 = V.new("sub1.x", [1..0], 0)
    v4 = V.new("sub1.x", nil, 1)
    (v1 == v2).should == true
    (v1 == v3).should == false
    (v1 == v4).should == false
    [v2, v3, v4].include?(v1).should == true
  end

  it 'ports can be connected to a value via other ports' do
    class Block
      include Origen::Model
      def initialize
        port :pa, size: 8
        sub_block :sub1
      end
    end

    b = Block.new
    b.sub1.add_port :pb, size: 8
    b.sub1.pb.connect_to(0x5A)
    b.pa.connect_to(b.sub1.pb)
    n = b.sub1.pb
    n.data.should == 0x5A
    b.pa.data.should == 0x5A
    b.pa[7..4].data.should == 0x5
  end

  it 'ports can be connected to a register' do
    class Block
      include Origen::Model
      def initialize
        port :pa, size: 8
        port :pb, size: 8
        sub_block :sub1, class_name: "Sub"
        pa.connect_to(sub1.pa)
        pb.connect_to(sub1.pb)
      end
    end

    class Sub
      include Origen::Model
      def initialize
        port :pa, size: 8
        port :pb, size: 8
        reg :rega, 0, size: 8 do |reg|
          reg.bits 7..4, :upper
          reg.bits 3..0, :lower
        end
        pa.connect_to(rega)
        pb[3..0].connect_to(rega.upper)
        pb[7..4].connect_to(rega.lower)
      end
    end

    b = Block.new
    n = b.pa
    n.data.should == 0
    b.sub1.rega.write(0x5A)
    n.data.should == 0x5A
    n[3..0].data.should == 0xA
    n[7..4].data.should == 0x5
    debugger
    b.pb.data.should == 0xA5
  end
end
