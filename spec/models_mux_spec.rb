require 'spec_helper'

describe 'The Origen MUX model' do
  class MuxBlock
    include Origen::Model

    def initialize
      sub_block :mux, class_name: "Origen::Models::Mux", select_lines: 2,
        size: 8

      port :a, size: 8
      port :b, size: 8
      port :c, size: 8
      port :sel, size: 2

      mux.input0.connect_to(a)
      mux.input1.connect_to(b)
      mux.input2.connect_to(c)
      mux.input3.connect_to(b)

      mux.select.connect_to(sel)
    end
  end

  it 'can be instantiated in a parent model' do
    b = MuxBlock.new
    b.mux.is_a?(Origen::Models::Mux).should == true
    b.mux.parent.should == b
    b.mux.size.should == 8
    b.mux.select_lines.should == 2
    b.mux.input0.size.should == 8
  end

  it 'can select the correct input' do
    b = MuxBlock.new
    b.a.drive(0x11)
    b.b.drive(0x22)
    b.c.drive(0x33)
  
    b.mux.output.data.should == undefined
    b.sel.drive(0)
    b.mux.output.data.should == 0x11
    b.sel.drive(1)
    b.mux.output.data.should == 0x22
    b.sel.drive(2)
    b.mux.output.data.should == 0x33
    b.sel.drive(3)
    b.mux.output.data.should == 0x22
  end
end
