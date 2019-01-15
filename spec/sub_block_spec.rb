require "spec_helper"

module SubBlocksSpec

  class Top
    include Origen::Model

    def initialize
      @path = "ftf2"
      domain :ips
      domain :ahb, endian: :little

      sub_block :sub1, class_name: "Sub1", base_address: 0x1000_0000, path: "ci.ci_regs"
      sub_block :sub3, base_address: 0x3000_0000, path: "blah", domain: :ahb, some_attr: "hello"
      sub_block :sub4
      sub_block :sub5, class_name: "Sub3", abs_path: "ftf3.blah"
      sub_block :sub6, class_name: "Sub3"
      sub_block :sub7, class_name: "Sub2", path: :hidden, base_address: 0x7000_0000

      sub_block_group :subgroups, class_name: "SubBlocksSpec::Subs" do
        sub_block :subitem0, class_name: "SubItem0", base_address: 0x000, some_attr: "There are two kinds of people"
        sub_block :subitem1, class_name: "SubItem1", base_address: 0x200, some_attr: "in the world.  Those who can "
        sub_block :subitem2, class_name: "SubItem2", base_address: 0x400, some_attr: "extrapolate from incomplete data"
      end
    end

    def sub2
      @sub2 ||= sub_block :sub2, class_name: "Sub2", base_address: 0x2000_0000, some_attr: "hello"
    end
  end

  class Sub1
    include Origen::Model

    def initialize
      reg :reg1, 0x100 do
        bits 31..0, :data
      end
    end
  end

  class Sub2
    include Origen::Model
    attr_reader :some_attr

    def initialize(options={})
      @some_attr = options[:some_attr]
      sub_block :sub3, class_name: "Sub1", base_address: 0x0001_0000
    end
  end

  class Sub3
    include Origen::Model

    def initialize
      reg :reg1, 0x100, path: "reg1_reg" do
        bits 11..10, :d7
        bits 9..8,   :d6, abs_path: "blah.d6_reg"
        bits 7..6,   :d5, path: "d5_reg"
        bits 5..4,   :d4, path: ".d4_reg"
        bit  3,      :d3
        bit  2,      :d2, abs_path: "blah.d2_reg"
        bit  1,      :d1, path: "d1_reg"
        bit  0,      :d0, path: ".d0"
      end
    end
  end

  class Subs < ::Array
    def <<(sub_block)
      push sub_block
    end
  end

  class SubItem0
    include Origen::Model
    attr_reader :some_attr

    def initialize(options={})
      @some_attr = options[:some_attr]
      reg :reg1, 0x100 do
        bits 31..0, :data
      end
    end

  end
  class SubItem1
    include Origen::Model
    attr_reader :some_attr

    def initialize(options={})
      @some_attr = options[:some_attr]
      reg :reg1, 0x100 do
        bits 31..0, :data
      end
    end

  end
  class SubItem2
    include Origen::Model
    attr_reader :some_attr

    def initialize(options={})
      @some_attr = options[:some_attr]
      reg :reg1, 0x100 do
        bits 31..0, :data
      end
    end
  end

  # Run all of these specs twice, once with immediately instantiating sub-blocks and once with lazy instantiation
  [false, true].each do |lazy_setting|

    describe "Register base addressing and hierarchy with #{lazy_setting ? 'LAZY' : 'IMMEDIATE'} instantiation" do

      before :all do
        Origen::SubBlocks.lazy = lazy_setting
      end

      it "sub-block placeholders should look like the underlying sub-block to users" do
        c = Top.new
        c.sub1.is_a?(Origen::SubBlocks::Placeholder).should == lazy_setting
        c.sub1.is_a?(Sub1).should == true
        c.sub1.class.should == Sub1
        c.sub1.is_a?(Origen::SubBlocks::Placeholder).should == lazy_setting
        c.sub1.reg1
        c.sub1.is_a?(Origen::SubBlocks::Placeholder).should == false
        c.sub1.is_a?(Sub1).should == true
      end

      it "sub-block placeholders should pass equality comparison with their materialized self (and vice versa)" do
        c = Top.new
        placeholder = c.sub1
        c.sub1.reg1
        materialized = c.sub1
        placeholder.is_a?(Origen::SubBlocks::Placeholder).should == lazy_setting
        materialized.is_a?(Origen::SubBlocks::Placeholder).should == false
        (placeholder == materialized).should == true
        result = (materialized == placeholder)
        result.should == true
        
      end

      it "owner and parent methods work" do
        c = Top.new
        b = c.sub1
        b.owner.should == c
        b.parent.should == c
      end

      it "multiple instances can be declared" do
        class Top2
          include Origen::Model
          def initialize
            sub_block  :vreg, class_name: "Sub1", base_address: 0x1000_0000
            sub_blocks :atd, instances: 2, class_name: "Sub1", base_address: 0x2000_0000
            sub_blocks :osc, instances: 2, class_name: "Sub1", base_address: 0x3000_0000, base_address_step: 0x1000
            sub_blocks :pmc, instances: 2, class_name: "Sub1", base_address: [0x4000_0000, 0x4001_0000]
          end
        end

        c = Top2.new
        c.vreg.base_address.should == 0x1000_0000
        c.atd0.base_address.should == 0x2000_0000
        c.atd1.base_address.should == 0x2000_0000
        c.atd0.reg1.write(0x55)
        c.atd0.reg1.data.should == 0x55
        c.atd1.reg1.data.should == 0x00
        c.atd1.reg1.write(0xAA)
        c.atd0.reg1.data.should == 0x55
        c.atd1.reg1.data.should == 0xAA
        c.atds.size.should == 2
        c.osc0.base_address.should == 0x3000_0000
        c.osc1.base_address.should == 0x3000_1000
        c.pmc0.base_address.should == 0x4000_0000
        c.pmc1.base_address.should == 0x4001_0000
      end

      it "base address attribute can be set when instantiating a register owner" do
        c = Top.new
        c.respond_to?(:sub1).should == true
        c.sub1.reg_base_address.should == 0x1000_0000
        c.sub1.base_address.should == 0x1000_0000
      end

      it "can properly route get pass/fail for has_reg? method" do
        c = Top.new
        c.sub1.has_reg?(:reg1).should == true
        c.sub1.has_reg?(:reg1000).should == false # This previously returned an Exception
      end

      it "base addresses get applied to registers" do
        c = Top.new
        c.sub1.reg(:reg1).address(relative: true).should == 0x100
        c.sub1.reg(:reg1).offset.should == 0x100
        c.sub1.reg(:reg1).address.should == 0x1000_0100
      end

      it "base addresses can be built in stages" do
        Top.new.sub2.sub3.reg(:reg1).address.should == 0x2001_0100
      end

      it "children should know their parents" do
        c = Top.new
        c.sub1.parent.should == c
        c.sub2.sub3.parent.should == c.children[:sub2]
        c.sub2.sub3.parent.parent.should == c
      end

      it "(hdl) paths can be constructed" do
        c = Top.new
        c.path.should == "ftf2"
        c.sub1.path.should == "ftf2.ci.ci_regs"
        c.sub1.path(relative_to: c).should == "ci.ci_regs"
        c.sub2.path.should == "ftf2.sub2"
        c.sub2.sub3.path.should == "ftf2.sub2.sub3"
        c.sub7.sub3.path.should == "ftf2.sub3"
        c.sub2.sub3.reg(:reg1).path.should == "ftf2.sub2.sub3.reg1"
        c.sub2.sub3.reg(:reg1).path(relative_to: c).should == "sub2.sub3.reg1"
        c.sub7.sub3.reg(:reg1).path.should == "ftf2.sub3.reg1"
        c.sub7.sub3.reg(:reg1).path(relative_to: c).should == "sub3.reg1"
        c.sub1.reg(:reg1).path.should == "ftf2.ci.ci_regs.reg1"
        c.sub1.reg(:reg1).path(relative_to: c).should == "ci.ci_regs.reg1"
        c.sub1.reg(:reg1).path(relative_to: c.sub1).should == "reg1"
        c.sub1.reg(:reg1).bits(:data).path.should == "ftf2.ci.ci_regs.reg1[31:0]"
        c.sub1.reg(:reg1).bits(:data).path(relative_to: c).should == "ci.ci_regs.reg1[31:0]"
        c.sub1.reg(:reg1).bits(:data).path(relative_to: c.sub1.reg(:reg1)).should == "[31:0]"
      end

      it "full paths can be set" do
        c = Top.new
        c.sub1.reg(:reg1).path.should == "ftf2.ci.ci_regs.reg1"
        c.sub1.reg(:reg1).full_path = "blah.blah"
        c.sub1.reg(:reg1).path.should == "blah.blah"
      end

      it "absolute paths can be set on objects in the tree and this will stop further look up" do
        c = Top.new
        c.sub5.path.should == "ftf3.blah"
        c.sub5.reg(:reg1).path.should == "ftf3.blah.reg1_reg"
        c.sub5.reg(:reg1).path.should == "ftf3.blah.reg1_reg"
        c.sub5.reg(:reg1).hdl_path.should == "ftf3.blah.reg1_reg"
        c.sub6.path.should == "ftf2.sub6"
        c.sub6.reg(:reg1).path.should == "ftf2.sub6.reg1_reg"

        b = c.sub5.reg(:reg1).bits(:d6)
        b.path.should == "blah.d6_reg"
        c.sub5.reg(:reg1).bits(:d7).path.should == "ftf3.blah.reg1_reg[11:10]"
        c.sub5.reg(:reg1).bits(:d5).path.should == "ftf3.blah.d5_reg"
        c.sub5.reg(:reg1).bits(:d4).path.should == "ftf3.blah.reg1_reg.d4_reg"
        c.sub5.reg(:reg1).bits(:d3).path.should == "ftf3.blah.reg1_reg[3]"
        c.sub5.reg(:reg1).bits(:d2).path.should == "blah.d2_reg"
        c.sub5.reg(:reg1).bits(:d1).path.should == "ftf3.blah.d1_reg"
        c.sub5.reg(:reg1).bits(:d0).path.should == "ftf3.blah.reg1_reg.d0"
      end

      it "default sub blocks will be generated when no class name is specified" do
        c = Top.new
        c.sub3.add_reg :reg1, 0x30, 32, data: { pos: 0, bits: 32 }
        c.sub3.reg(:reg1).address.should == 0x3000_0030
        c.sub3.reg(:reg1).path.should == "ftf2.blah.reg1"
        c.sub4.path.should == "ftf2.sub4"
        c.sub4.base_address.should == 0
      end

      it "default sub blocks can have attributes defined on the fly" do
        c = Top.new
        c.sub3.blah = 10
        c.sub3.blah.should == 10
      end

      it "the block form of adding registers works" do
        c = Top.new
        c.sub3.reg :reg1, 0x30 do |o|
          o.bits 31..0, :data, reset: 0xFFFF_FFFF
        end
        c.sub3.reg(:reg1).data.should == 0xFFFF_FFFF
      end

      it "additional options are passed to the class if specified" do
        Top.new.sub2.some_attr.should == "hello"
      end

      it "additional options are added as attributes to anonymous sub blocks" do
        Top.new.sub3.some_attr.should == "hello"
      end

      describe "register domains" do
        it "should be empty by default" do
          Sub2.new.sub3.reg(:reg1).domains.empty?.should == true
        end

        it "if not specified the register should inherit all domains from the parent" do
          c = Top.new
          c.sub1.reg(:reg1).domains.should == c.domains
        end

        it "if specified then only that subset of domains should be returned" do
          c = Top.new
          c.sub3.domains.should == {ahb: c.domains[:ahb]}.with_indifferent_access
          c.sub3.add_reg :reg1, 0x30, 32, data: { pos: 0, bits: 32 }
          c.sub3.reg(:reg1).domains.should == {ahb: c.domains[:ahb]}.with_indifferent_access
        end

        it "base addresses can be applied per domain" do
          class BATop
            include Origen::TopLevel

            def initialize
              domain :ips
              domain :ahb

              sub_block :sub1, class_name: "BASub1", base_address: 0x1000_0000
              sub_block :sub2, class_name: "BASub1", base_address: { ips: 0x2000_0000, ahb: 0x3000_0000 }
            end
          end

          class BASub1
            include Origen::Model

            def initialize
              reg :reg1, 0x200 do
                bits 31..0, :data
              end
              sub_block :sub1, class_name: "BASub2", domain: :ips
              sub_block :sub2, class_name: "BASub2", domain: :ahb
            end
          end

          class BASub2
            include Origen::Model

            def initialize
              reg :reg1, 0x200 do
                bits 31..0, :data
              end
              sub_block :sub1, class_name: "BASub3", base_address: 0x100_0000
            end
          end

          class BASub3
            include Origen::Model

            def initialize
              reg :reg1, 0x200 do
                bits 31..0, :data
              end
            end
          end

          Origen.app.unload_target!

          BATop.new

          # Test that domains inherit properly
          $dut.domains.should == {ahb: $dut.domains[:ahb], ips: $dut.domains[:ips]}.with_indifferent_access
          $dut.sub1.domains.should == {ahb: $dut.domains[:ahb], ips: $dut.domains[:ips]}.with_indifferent_access
          $dut.sub2.domains.should == {ahb: $dut.domains[:ahb], ips: $dut.domains[:ips]}.with_indifferent_access
          $dut.sub1.sub1.domains.should == {ips: $dut.domains[:ips]}.with_indifferent_access
          $dut.sub1.sub2.domains.should == {ahb: $dut.domains[:ahb]}.with_indifferent_access
          $dut.sub1.sub1.reg1.domains.should == {ips: $dut.domains[:ips]}.with_indifferent_access
          $dut.sub1.sub2.reg1.domains.should == {ahb: $dut.domains[:ahb]}.with_indifferent_access

          $dut.sub1.sub1.reg1.address.should == 0x1000_0200
          $dut.sub1.sub2.reg1.address.should == 0x1000_0200
          $dut.sub1.sub1.sub1.reg1.address.should == 0x1100_0200
          $dut.sub1.sub2.sub1.reg1.address.should == 0x1100_0200
          $dut.sub2.sub1.reg1.address.should == 0x2000_0200
          $dut.sub2.sub2.reg1.address.should == 0x3000_0200
          $dut.sub2.sub1.sub1.reg1.address.should == 0x2100_0200
          $dut.sub2.sub2.sub1.reg1.address.should == 0x3100_0200
          $dut.sub1.reg1.address(domain: :ips).should == 0x1000_0200
          $dut.sub1.reg1.address(domain: :ahb).should == 0x1000_0200
          $dut.sub2.reg1.address(domain: :ips).should == 0x2000_0200
          # Address is cached here, causing fail...
          $dut.sub2.reg1.address(domain: :ahb).should == 0x3000_0200
        end

        it "bit index is output correctly when a parent register's path is hidden" do
          class BITop
            include Origen::TopLevel

            def initialize
              @path = :hidden
              sub_block :sub1, class_name: "BISub"
            end
          end

          class BISub
            include Origen::Model

            def initialize
              reg :dr, 0, path: :hidden do |reg|
                bits 31..0, :data
              end
            end
          end

          Origen.app.unload_target!

          BITop.new

          $dut.sub1.dr[0].path.should == "sub1[0]"
          $dut.sub1.dr[7..0].path.should == "sub1[7:0]"
        end

        it 'options passed to sub_block definitions are applied when the class is named' do
          class Top1
            include Origen::TopLevel

            def initialize
              sub_block :sub1, class_name: "Sub1", x: 5, y: 10
            end
          end

          class Sub1
            include Origen::Model
            attr_accessor :x
            attr_reader :y
          end

          Origen.app.unload_target!

          Top1.new

          $dut.sub1.x.should == 5
          $dut.sub1.y.should == 10
        end

        it 'on_create callbacks in sub_block models get called' do
          class TopLevel
            include Origen::TopLevel

            def initialize
              sub_block :sub1, class_name: "Sub1"
            end
          end

          class Sub1
            include Origen::Model
            attr_reader :on_create_called

            def on_create
              @on_create_called ||= 0
              @on_create_called += 1
            end
          end

          class Sub1Controller
            include Origen::Controller
            attr_reader :controller_on_create_called

            def wrapped?
              true
            end

            def on_create
              @controller_on_create_called ||= 0
              @controller_on_create_called += 1
            end
          end

          Origen.app.unload_target!
          Origen.target.temporary = -> { TopLevel.new }
          Origen.load_target

          dut.sub1.on_create_called.should == 1
          dut.sub1.wrapped?.should == true
          dut.sub1.controller_on_create_called.should == 1
        end
      end

      describe "part loading" do
        it "can be done from within the sub-block class's initialize method" do
          Origen.app.unload_target!
          OrigenCoreSupport::MySOC.new
          dut.my_sub_block_1.params.param1.should == 100
          dut.my_sub_block_1.params.param2.should == 20
          dut.my_sub_block_1.params.param3.should == 300
        end

        it "can be done via a load_part argument passed to sub_block" do
          Origen.app.unload_target!
          OrigenCoreSupport::MySOC.new
          dut.my_sub_block_2.params.param1.should == 10
          dut.my_sub_block_2.params.param2.should == 200
          dut.my_sub_block_2.params.param3.should == 300
        end
      end

      describe "sub block groups" do
        before :all do
        end

        it "subgroups container and sub-items exist as expected" do
          c = Top.new
          c.subgroups.is_a?(SubBlocksSpec::Subs).should == true
          c.subgroups.count.should == 3
          c.subgroups[0].is_a?(SubItem0).should == true
          c.subgroups[1].is_a?(SubItem1).should == true
          c.subgroups[2].is_a?(SubItem2).should == true
        end

        it "subitems exist standalone from container" do 
          c = Top.new
          c.subitem0.is_a?(SubItem0).should == true
          c.subitem1.is_a?(SubItem1).should == true
          c.subitem2.is_a?(SubItem2).should == true
        end

        it "subitems have correct attributes and regs" do
          c = Top.new
          c.subgroups[0].base_address.should == 0x000
          c.subgroups[1].base_address.should == 0x200
          c.subgroups[2].base_address.should == 0x400
          c.subgroups[0].some_attr.should == "There are two kinds of people"
          c.subgroups[1].some_attr.should == "in the world.  Those who can "
          c.subgroups[2].some_attr.should == "extrapolate from incomplete data"
        end

        it "subitem registers are writeable and no naming conflicts" do
          c = Top.new
          c.subgroups[0].reg1
          c.subgroups[1].reg1
          c.subgroups[2].reg1
          c.subgroups[0].reg1.write(0x55)
          c.subgroups[0].reg1.data.should == 0x55
          c.subgroups[1].reg1.data.should == 0x00
          c.subgroups[2].reg1.data.should == 0x00
          c.subgroups[1].reg1.write(0xAA)
          c.subgroups[0].reg1.data.should == 0x55
          c.subgroups[1].reg1.data.should == 0xAA
          c.subgroups[2].reg1.data.should == 0x00
          c.subgroups[2].reg1.write(0xBB)
          c.subgroups[0].reg1.data.should == 0x55
          c.subgroups[1].reg1.data.should == 0xAA
          c.subgroups[2].reg1.data.should == 0xBB
        end

        it "default to Array if no container class provided" do
          class Top2
            include Origen::Model
            def initialize
              sub_block_group :subgroups do
                sub_block :subitem0, class_name: "SubItem0", base_address: 0x000, some_attr: "never"
                sub_block :subitem1, class_name: "SubItem1", base_address: 0x200, some_attr: "forget"
                sub_block :subitem2, class_name: "SubItem2", base_address: 0x400, some_attr: "the"
              end
            end
          end
          d = Top2.new
          d.subgroups.is_a?(Array).should == true
          d.subgroups.count.should == 3
          d.subgroups[0].is_a?(SubItem0).should == true
          d.subgroups[1].is_a?(SubItem1).should == true
          d.subgroups[2].is_a?(SubItem2).should == true
        end

      end
    end
  end
end
