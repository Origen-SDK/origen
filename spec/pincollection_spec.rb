require 'spec_helper'

# Some dummy classes to test out the PinCollection module
class PinGroupDut
  include Origen::TopLevel

  attr_accessor :configuration

  def initialize
    add_pins :pdata, size: 8
    add_pins :pinx
    add_pins :piny
    add_pins :pinz
    add_pin_group :group1, :pinx, :piny, :pinz
  end
end

describe 'Origen PinCollection API v3' do

  before :each do
    Origen.load_target('configurable', dut: PinGroupDut)
  end

  describe 'PinCollection Functionality' do
    it 'groups added correctly' do
      $dut.pin_groups.size.should == 2
      $dut.pin_groups.include?(:pdata).should == true
      $dut.pin_groups.include?(:pinx).should == false
    end

    it "can be sorted" do
      $dut.add_pin_group :not_in_order, :pinz, :pinx, :piny
      # By default will sort in alphabetical order by ID
      $dut.pins(:not_in_order).sort!
      $dut.pins(:not_in_order)[0].name.should == :pinx
      $dut.pins(:not_in_order)[1].name.should == :piny
      $dut.pins(:not_in_order)[2].name.should == :pinz
      # Example of a custom sort, here in reverse alphabetical
      # order by ID
      $dut.pins(:not_in_order).sort! do |a, b|
        b.id <=> a.id
      end
      $dut.pins(:not_in_order)[0].name.should == :pinz
      $dut.pins(:not_in_order)[1].name.should == :piny
      $dut.pins(:not_in_order)[2].name.should == :pinx
    end

    it 'drive/driving?/high_voltage? methods work' do
      $dut.pins(:pdata).data.should       == 0
      $dut.pins(:pdata).drive(0xF)
      $dut.pins(:pdata).data.should       == 15
      $dut.pins(:pdata0).data.should      == 1
      $dut.pins(:pdata)[1].data.should    == 1
      $dut.pins(:pdata)[-1].data.should   == 0
      $dut.pins(:pdata7).data.should      == 0
      $dut.pins(:pdata).drive_hi
      p = $dut.pins(:pdata).data
      p.should == 255
      $dut.pins(:pdata).driving?.should   == true
      $dut.pins(:pdata0).state.should      == :drive
      $dut.pin_group(:pdata).drive_lo
      $dut.pins(:pdata).data.should       == 0
      $dut.pin_group(:pdata).drive_very_hi
      q = $dut.pins(:pdata).data
      q.should == p
      $dut.pins(:pdata1).state.should      == :drive_very_hi
      $dut.pin_group(:pdata).high_voltage?.should == true
    end

    it 'drive_mem/driving_mem? methods work' do
      $dut.pins(:pdata).drive_mem
      $dut.pins(:pdata0).state.should == :drive_mem
      $dut.pins(:pdata).driving_mem?.should == true
    end

    it 'expect_mem/comparing_mem? method works' do
      $dut.pins(:group1).comparing_mem?.should == false
      $dut.pins(:group1).expect_mem
      $dut.pins(:group1).comparing_mem?.should == true
    end

    it 'toggle method works' do
      $dut.pins(:pdata).drive_hi
      $dut.pins(:pdata).data.should == 255
      $dut.pins(:pdata).toggle
      $dut.pins(:pdata).data.should == 0
      $dut.pins(:pdata).drive(0xF)
      $dut.pins(:pdata).toggle
      $dut.pins(:pdata).data.should == 0xF0
    end

    it 'repeat_previous/repeat_previous? method works' do
      $dut.pin_group(:group1).repeat_previous?.should == false
      $dut.pin_group(:group1).repeat_previous = true
      $dut.pin_group(:group1).repeat_previous?.should == true
      $dut.pin_group(:group1)[0].repeat_previous?.should == true
      $dut.pin(:pinz).repeat_previous?.should == true
    end

    it 'capture/to_be_captured? method works' do
      $dut.pin(:pdata).to_be_stored?.should == false
      $dut.pin(:pdata)[3..0].capture
      $dut.pin(:pdata).to_be_captured?.should == false
      $dut.pin(:pdata)[3..0].is_to_be_captured?.should == true
      $dut.pin(:pdata).store
      $dut.pin(:pdata).is_to_be_stored?.should == true
    end

    it 'restore_state method works' do
      $dut.pins(:group1).drive_hi
      $dut.pins(:group1).driving?.should == true
      $dut.pins(:group1).restore_state do
        $dut.pins(:group1).dont_care
        $dut.pins(:group1).driving?.should == false
      end
      $dut.pins(:group1).driving?.should == true
    end

    it 'assert/comparing? methods work' do
      $dut.pin(:pdata).comparing?.should      == false
      $dut.pin(:pdata).assert(0x5e)
      $dut.pin(:pdata).data.should            == 0x5e
      $dut.pin(:pdata).compare_hi
      $dut.pin(:pdata).data.should            == 0xff
      $dut.pins(:pdata0).comparing?.should    == true
      $dut.pin(:pdata).comparing?.should      == true
      $dut.pin_group(:pdata).expect_lo
      $dut.pin(:pdata).data.should            == 0
      $dut.pin(:pdata)[-1].comparing?.should  == true
    end

    it 'dont_care method works' do
      $dut.pin(:pdata).compare_hi
      $dut.pin(:pdata).comparing?.should      == true
      $dut.pin(:pdata)[7..4].dont_care
      $dut.pins(:pdata)[6].state.should       == :dont_care
      $dut.pins(:pdata)[3].state.should       == :compare
      $dut.pin(:pdata).comparing?.should      == false
      $dut.pin_group(:pdata).dont_care
      $dut.pin(:pdata)[3].comparing?          == false
    end

    it 'inverted? method works' do
      $dut.add_pin(:pin0_b, invert: true) # add inverted pin0
      $dut.add_pin(:pin1_b, invert: true) # add inverted pin1
      $dut.pin(:group1).add_pin(:pin0_b)
      $dut.add_pin_group(:all_inverted, :pin0_b, :pin1_b)
      $dut.pin(:group1).inverted?.should == false
      $dut.pin(:all_inverted).inverted?.should == true
    end

    it 'map is endian-aware' do
      $dut.add_pins :porta, size: 8
      $dut.pin_group(:porta).endian.should == :big
      $dut.pin(:porta)[0].id.should == :porta0
      first = nil
      $dut.pin_group(:porta).each { |i| first ||= i.id }
      first.should == :porta7
      ids = $dut.pin_group(:porta).map { |i| i.id }
      ids.first.should == :porta7

      $dut.add_pins :portb, size: 8, endian: :little
      $dut.pin_group(:portb).endian.should == :little
      $dut.pin(:portb)[0].id.should == :portb0
      first = nil
      $dut.pin_group(:portb).each { |i| first ||= i.id }
      first.should == :portb0
      ids = $dut.pin_group(:portb).map { |i| i.id }
      ids.first.should == :portb0
    end

    it 'to_vector method works' do
      $dut.add_pins :be, size: 4
      $dut.add_pins :le, size: 4, endian: :little
      be = $dut.pins(:be)
      le = $dut.pins(:le)
      le.endian.should == :little
      tester = OrigenTesters::J750.new
      be.to_vector.should == 'XXXX'
      le.to_vector.should == 'XXXX'
      be.drive(0b1100)
      le.drive(0b1100)
      be.to_vector.should == '1100'
      le.to_vector.should == '0011'
      be[2].dont_care
      be.to_vector.should == '1X00'
      be[0].assert(1)
      be.to_vector.should == '1X0H'
    end

    it 'vector_formatted_value= works' do
      $dut.add_pins :be, size: 4
      $dut.add_pins :le, size: 4, endian: :little
      be = $dut.pins(:be)
      le = $dut.pins(:le)
      tester = OrigenTesters::J750.new
      be.vector_formatted_value = 'X10L'
      be.invalidate_vector_cache
      be.to_vector.should == 'X10L'
      le.vector_formatted_value = '-2CE'
      le.invalidate_vector_cache
      le.vector_formatted_value = '-2CE'
    end
  end

  describe 'v3 Backwards Compatibility' do
    it 'add_pin_group_alias methods work' do
      $dut.add_pin_group_alias(:g1, :group1)
      $dut.pin_groups.size.should == 3 # pin group added
      $dut.pin(:g1).map { |i| i }.join(' ').should == $dut.pin(:group1).map { |i| i }.join(' ')
      $dut.add_pin_group_alias(:datums, :pdata)
      $dut.pin_groups.size.should == 4 # pin group added
      $dut.pin(:datums).map { |i| i }.join(' ').should == $dut.pin(:pdata).map { |i| i }.join(' ')
    end

    it 'add_pin_group :g2, :g1 works' do
      $dut.add_pin_group(:g1, :group1)
      $dut.pin_groups.size.should == 3
      $dut.pin_group(:g1).map { |i| i }.join(' ').should == $dut.pins(:group1).map { |i| i }.join(' ')
    end

    it 'groups/belongs_to_a_pin_group? methods work' do
      $dut.pin(:pdata2).groups.include?(:pdata).should == true
      $dut.add_pin_group(:dis_data, :pdata2)
      $dut.pin(:pdata2).groups.size.should == 2
      $dut.add_pin(:loner)
      $dut.pins(:loner).belongs_to_a_pin_group?.should == false
      $dut.pins(:pinx).belongs_to_a_pin_group?.should == true
      $dut.pins(:pinx).belongs_to_a_pin_group?.should == true
    end

    it 'add_pin_alias :g2, :g1, pins: [3..0] works' do
      $dut.add_pin_alias(:pd5, :pdata, pin: 5)
      $dut.add_pin_alias(:pd_lower, :pdata, pins: [3..0])
      $dut.add_pin_alias(:pd_upper, :pdata, pins: [7, 6, 5, 4])
      $dut.pin_groups.size.should == 4
      $dut.pin(:pd5).is_alias_of?($dut.pin_groups(:pdata)[5].id).should == true
      $dut.pins(:pdata)[5].has_alias?(:pd5).should == true
      $dut.pins(:pd_lower).each do |i|
        $dut.pin_groups(:pdata)[3..0].include?(i).should == true
      end
      $dut.pins(:pd_upper).each do |i|
        $dut.pin_groups(:pdata)[7, 6, 5, 4].include?(i).should == true
      end
    end

    it 'pin_pattern_order works' do
      Origen.app.pin_pattern_order.size.should == 0
      $dut.pin_pattern_order(:pinx, :piny, :pdata)
      Origen.app.pin_pattern_order.size.should == 3
      Origen.app.pin_pattern_order.last.is_a?(Hash).should == false
    end

    it 'pin_pattern_order only: true option works' do
      $dut.pin_pattern_order(:pinx, :piny, only: true)
      Origen.app.pin_pattern_order.size.should == 3
      Origen.app.pin_pattern_order.last.is_a?(Hash).should == true
      $tester.current_pin_vals.size.should == 3
    end

    it 'pin_pattern_order works for groups composed of pins from another pin group' do
      $dut.add_pin :clk
      $dut.add_pins :cti_data, size: 5
      $dut.add_pin :reset
      $dut.add_pin_alias :nvm_fail, :cti_data2
      $dut.add_pin_alias :nvm_done, :cti_data3
      $dut.pin_pattern_order :clk, :nvm_fail, :nvm_done, :cti_data, :reset, only: true
      pin_list = $tester.ordered_pins.map do |p|
        if Origen.app.pin_pattern_order.include?(p.id)
          p.id # specified name overrides pin name
        else
          p.name
        end
      end.join(', ')
      pin_list.should == 'clk, nvm_fail, nvm_done, cti_data4, cti_data1, cti_data0, reset'
    end

    it 'pin_pattern_exclude works' do
      # pdata, pinx, piny, pinz inherited from initialize method
      $dut.add_pin :pin1
      $dut.add_pins :pin_grp1, size: 5
      $dut.add_pin :pin2
      $dut.add_pin :pin3
      $dut.add_pin :pin4
      $dut.add_pin :pin5
      $dut.add_pin :pin6
      $dut.pin_pattern_order :pin1, :pin_grp1, :pin3
      $dut.pin_pattern_exclude :pin2, :pin4, :pinx, :piny, :pinz, :pdata
      pin_list = $tester.ordered_pins.map do |p|
        if Origen.app.pin_pattern_order.include?(p.id)
          p.id # specified name overrides pin name
        else
          p.name
        end
        if Origen.app.pin_pattern_exclude.include?(p.id)
          p.id # specified name overrides pin name
        else
          p.name
        end
      end.join(', ')
      pin_list.should == 'pin1, pin_grp1, pin3, pin5, pin6'
    end

    it 'current_pin_vals method works' do
      $dut.pin_pattern_order(:pinx, :piny, :pdata)
      $tester.current_pin_vals.should == 'X X XXXXXXXX X'
      $dut.pin(:pinx).drive(0)
      $dut.pin(:piny).drive(1)
      $dut.pin(:pdata).expect_lo
      $tester.current_pin_vals.should == '0 1 LLLLLLLL X'
    end

  end

end
