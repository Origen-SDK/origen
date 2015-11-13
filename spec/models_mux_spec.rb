require 'spec_helper'

describe 'The Origen MUX model' do
  class MuxBlock
    include Origen::Model

    def initialize
      sub_block :mux, class_name: "Origen::Models::Mux"

      port :a
      port :b
      port :c
      port :sel

      mux.select_by sel

      mux.input0.connect_to(a)
      mux.input1.connect_to(b)
      mux.input2.connect_to(c)
      mux.input3.connect_to(b)

      mux.select.connect_to(sel)
    end
  end


  # // implements compare_out = (check_mismatch) ? different : same
  # ScanMux compare_out SelectedBy check_mismatch[1:0] {
  #   1’b0,1’b1 | 1’b1,1’b0 : different;
  #   1’b1,1’b1 | 1’b0,1’b0 : same;
  # }

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

  it 'example 1' do
    # Based on this real life example
    #
    #   ScanMux M_bypass SelectedBy tpr_bypass, tpr_input_en, tpr_output_en, tpr_config {
    #      4'b0100 : R_2[0];
    #      4'b1XXX : tdi;
    #   }
    class MuxBlock2
      include Origen::Model

      def initialize
        port :a
        port :b
        port :c
        port :tpr_bypass
        port :tpr_input_en
        port :tpr_output_en
        port :tpr_config

        sub_block :mux, class_name: "Origen::Models::Mux" do |mux|
          mux.select_by tpr_bypass, tpr_input_en, tpr_output_en, tpr_config
          mux.option 0b0100, a
          mux.option :b4_1XXX, b
        end

        mux.output.connect_to c
      end
    end

    b = MuxBlock2

    b.c.data.should == undefined
  end
end
