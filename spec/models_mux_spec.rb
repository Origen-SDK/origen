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

      mux.option 0, a
      mux.option [1,3], b
      mux.option 2, c
      mux.option 4, a[3..0], b[3..0]
    end
  end

  it 'can be instantiated in a parent model' do
    b = MuxBlock.new
    b.mux.is_a?(Origen::Models::Mux).should == true
    b.mux.parent.should == b
  end

  it 'can select the correct input' do
    b = MuxBlock.new
    b.a.drive(0x11)
    b.b.drive(0x22)
    b.c.drive(0x33)
  
    #b.mux.output.data.should == undefined
    b.sel.drive(0)
    b.mux.output.data.should == 0x11
    b.sel.drive(1)
    b.mux.output.data.should == 0x22
    b.sel.drive(2)
    b.mux.output.data.should == 0x33
    b.sel.drive(3)
    b.mux.output.data.should == 0x22
    b.sel.drive(4)
    b.mux.output.data.should == 0x12
  end

  it 'example 1' do
    # Based on this real life 1687 ICL example:
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
        port :tpr_bypass, size: 1
        port :tpr_input_en, size: 1
        port :tpr_output_en, size: 1
        port :tpr_config, size: 1

        sub_block :mux, class_name: "Origen::Models::Mux" do |mux|
          mux.select_by tpr_bypass, tpr_input_en, tpr_output_en, tpr_config
          mux.option 0b0100, a
          mux.option :b4_1XXX, b
        end

        mux.output.connect_to c
        #c.connect_to mux.output
      end
    end

    b = MuxBlock2.new

    b.a.drive(0x11)
    b.b.drive(0x22)
    b.tpr_bypass.drive(1)
    b.c.data.should == 0x22
    b.tpr_bypass.drive(0)
    b.c.data.should == 0 #undefined
    b.tpr_input_en.drive(1)
    b.tpr_output_en.drive(0)
    b.tpr_config.drive(0)
    b.c.data.should == 0x11
  end
end
