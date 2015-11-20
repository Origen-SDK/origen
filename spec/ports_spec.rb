require 'spec_helper'

describe 'Ports' do

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

  it 'creates lower-cased accessors' do
    class Block
      include Origen::Model

      def initialize
        port :DI, size: 8
        port :SR, size: 16 do |port|
          port.bits 7..0, :d1
        end
      end
    end

    b = Block.new
    b.DI.should == b.di
    b.SR.should == b.sr
  end

  it 'ports can be tied off to a value' do
    class Block
      include Origen::Model
      def initialize
        port :pa, size: 8
      end
    end

    b = Block.new
    b.pa.connect_to(0)
    b.pa.data.should == 0
    b.pa[4].data.should == 0
    b.pa[3..0].data.should == 0
    
    b = Block.new
    b.pa.connect_to(0x5A)
    n = b.pa
    n.data.should == 0x5A
    n = b.pa[3..0]
    n.data.should == 0xA
    b.pa[7..4].data.should == 0x5
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
    b.pa.connect_to "sub1.pb"
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
        pa.connect_to rega
        pb.connect_to rega.lower, rega.upper
      end
    end

    b = Block.new
    n = b.pa
    n.data.should == 0
    b.sub1.rega.write(0x5A)
    n.data.should == 0x5A
    n[3..0].data.should == 0xA
    n[7..4].data.should == 0x5
    b.pb.data.should == 0xA5
  end

  it 'ports can be driven' do
    class Block
      include Origen::Model
      def initialize
        port :pa, size: 8
        sub_block :sub1, class_name: "Sub"
        pa.connect_to(sub1.pa)
      end
    end

    class Sub
      include Origen::Model
      def initialize
        port :pa, size: 8
      end
    end

    b = Block.new
    b.pa.drive(1)
    n = b.pa
    n.data.should == 1
    n = b.sub1.pa
    n.data.should == 1
    b.pa.drive(0)
    b.sub1.pa.data.should == 0
  end

  it 'ports can be connected via a Proc' do
    class Block
      include Origen::Model

      attr_accessor :select

      def initialize
        port :pa, size: 8
        port :pb, size: 8
        port :pc, size: 8
        sub_block :sub1, class_name: "Sub"

        @select = :pa

        sub1.pa.connect_to do |i|
          send(select)
        end

        pc.connect_to do
          0xF0
        end
      end
    end

    class Sub
      include Origen::Model
      def initialize
        port :pa, size: 8
      end
    end

    b = Block.new

    b.pa.drive(0x11)
    b.pb.drive(0x22)
    b.sub1.pa.data.should == 0x11
    b.select = :pb
    b.sub1.pa.data.should == 0x22
    b.select = :pa
    b.sub1.pa.data.should == 0x11
    b.pc.data.should == 0xF0
  end

  it 'ports can be given a type and looked up by type' do
    class Block
      include Origen::Model

      def initialize
        port :si, type: :scan_in
        port :di, size: 8, type: :data_in
      end
    end

    b = Block.new
    b.si.type.should == :scan_in
    b.di.type.should == :data_in
    b.ports.by_type[:scan_in].first.should == b.si
  end

  it 'can be connected to ports, values or register bits' do
    class Block
      include Origen::Model

      def initialize
        port :p1
        port :p2
        port :p3, size: 8

        reg :reg1, 0x0, size: 8

        p1.connect_to p2[3..0], :b2_0, reg1[7..6]
        # Test works with single unsized item
        p3.connect_to p2[3..0], 0, reg1[7..6]
      end
    end

    b = Block.new

    n = b.p1
    n.data.should == 0#undefined
    b.p2.drive 0x55
    b.reg1.write 0xFF
    b.p1.data.should == 0x53
    b.p3.data.should == 0x53
    b.reg1.reset
    b.p1.data.should == 0x50
    b.p3.data.should == 0x50
  end
end
