require 'spec_helper'

# This module and double include below are required to give access to add_reg
# and similar methods from within the tests, but without adding the registers
# module to the global namespace which gives weird errors when the placeholder
# and other register objects pick up the top-level methods.
module RegTest

  include Origen::Registers

  describe Bit do

    include Origen::Registers

    def owner
      self
    end

    specify "reset value is assigned correctly" do
        Bit.new(self, 0).data.should == 0
        Bit.new(self, 0, res: 1).data.should == 1
    end

    specify "only LSB of reset value is stored" do
        Bit.new(self, 0, res: 0xFF).data.should == 1
    end

    it "can be written" do
        bit = Bit.new(self, 0).write(1)
        bit.data.should == 1
    end

    it "can be reset" do
        bit = Bit.new(self, 0).write(1)
        bit.reset
        bit.data.should == 0
        bit = Bit.new(self, 0, res: 1).write(0)
        bit.data.should == 0
        bit.reset
        bit.data.should == 1
    end

    specify "bit position is assigned correctly" do
        Bit.new(self, 0).position.should == 0
        Bit.new(self, 14).position.should == 14
    end

    it "can hold only one bit of data" do
        bit = Bit.new(self, 0)
        bit.write(0xFF)
        bit.data.should == 1
    end

    it "knows who it belongs to" do
        reg = Reg.new(self, 0x10, 16, :dummy)
        bit = Bit.new(reg, 0)
        bit.owner.should == reg
        bit.reset
        bit.owner.should == reg
    end

    it "returns the value required to write a given bit to a given value via the setting method" do
      class DUT
        include Origen::Registers
        attr_accessor :reg
        def initialize
          @reg = Reg.new(self, 0x10, 16, :dummy, b0: {pos: 0}, 
                                                b1: {pos: 4},
                                                b2: {pos: 9})
        end
      end
      reg = DUT.new.reg
        reg.bit(:b0).setting(1).should == 1
        reg.bit(:b0).setting(0xFF).should == 1
        reg.bit(:b0).setting(0xF0).should == 0
        reg.bit(:b1).setting(1).should == 0b10000
        reg.bit(:b1).setting(0).should == 0
        reg.bit(:b2).setting(1).should == 0x200
        reg.bit(:b2).setting(0).should == 0
    end

    it "returns the data shifted into position via the data_in_position method" do
        Bit.new(self, 0, res: 1).data_in_position.should == 0b1
        Bit.new(self, 3, res: 1).data_in_position.should == 0b1000
    end

    it "access codes can be assigned and queried" do
        b = Bit.new(self, 0)
        b.access.should == :rw
        b.rw?.should == true

        b = Bit.new(self, 0, access: :w1s)
        b.access.should == :w1s
        b.w1c?.should == false
        b.rw?.should == false
        b.w1s?.should == true

        b = Bit.new(self, 0, writable: false)
        b.access.should == :ro
        b.rw?.should == false
        b.ro?.should == true
    end
    
    it "access codes properly set readable/writable/w1c/etc. values" do
      class DUT2
        include Origen::Registers
        attr_accessor :access_types
        def initialize
          @access_types = Reg.new(self, 0x4, 32, :dummy, 
            readonly:              {pos: 31,      access: :ro},
            readwrite:             {pos: 30,      access: :rw},
            readclear:             {pos: 29,      access: :rc},
            readset:               {pos: 28,      access: :rs},
            writablereadclear:     {pos: 27,      access: :wrc},
            writablereadset:       {pos: 26,      access: :wrs},
            writeclear:            {pos: 25,      access: :wc},
            writeset:              {pos: 24,      access: :ws},
            writesetreadclear:     {pos: 23,      access: :wsrc},
            writeclearreadset:     {pos: 22,      access: :wcrs},
            write1toclear:         {pos: 21,      access: :w1c},
            write1toset:           {pos: 20,      access: :w1s},
            write1totoggle:        {pos: 19,      access: :w1t},
            write0toclear:         {pos: 18,      access: :w0c},
            write0toset:           {pos: 17,      access: :w0s},
            write0totoggle:        {pos: 16,      access: :w0t},
            write1tosetreadclear:  {pos: 15,      access: :w1src},
            write1toclearreadset:  {pos: 14,      access: :w1crs},
            write0tosetreadclear:  {pos: 13,      access: :w0src},
            write0toclearreadset:  {pos: 12,      access: :w0crs},
            writeonly:             {pos: 11,      access: :wo},
            writeonlyclear:        {pos: 10,      access: :woc},
            writeonlyreadzero:     {pos: 9,       access: :worz},
            writeonlyset:          {pos: 8,       access: :wos},
            writeonce:             {pos: 7,       access: :w1},
            writeonlyonce:         {pos: 6,       access: :wo1},
            readwritenocheck:      {pos: 5,       access: :dc},
            readonlyclearafter:    {pos: 4,       access: :rowz}
          )
        end
      end
      access_types = DUT2.new.access_types
      # Check access type set correctly
      access_types.bit(:readonly).access.should == :ro
      access_types.bit(:readwrite).access.should == :rw
      access_types.bit(:readclear).access.should == :rc
      access_types.bit(:readset).access.should == :rs
      access_types.bit(:writablereadclear).access.should == :wrc
      access_types.bit(:writeclear).access.should == :wc
      access_types.bit(:writeset).access.should == :ws
      access_types.bit(:writesetreadclear).access.should == :wsrc
      access_types.bit(:writeclearreadset).access.should == :wcrs
      access_types.bit(:write1toclear).access.should == :w1c
      access_types.bit(:write1toset).access.should == :w1s
      access_types.bit(:write0toclear).access.should == :w0c
      access_types.bit(:write0toset).access.should == :w0s
      access_types.bit(:write0totoggle).access.should == :w0t
      access_types.bit(:write1tosetreadclear).access.should == :w1src
      access_types.bit(:write1toclearreadset).access.should == :w1crs
      access_types.bit(:write0tosetreadclear).access.should == :w0src
      access_types.bit(:writeonly).access.should == :wo
      access_types.bit(:writeonlyclear).access.should == :woc
      access_types.bit(:writeonlyreadzero).access.should == :worz
      access_types.bit(:writeonlyset).access.should == :wos
      access_types.bit(:writeonce).access.should == :w1
      access_types.bit(:writeonlyonce).access.should == :wo1
      access_types.bit(:readwritenocheck).access.should == :dc
      access_types.bit(:readonlyclearafter).access.should == :rowz
      # Check 'base' access type for CrossOrigen export is set correctly
      access_types.bit(:readonly).base_access.should == 'read-only'
      access_types.bit(:readwrite).base_access.should == 'read-write'
      access_types.bit(:readclear).base_access.should == 'read-only'
      access_types.bit(:readset).base_access.should == 'read-only'
      access_types.bit(:writablereadclear).base_access.should == 'read-write'
      access_types.bit(:writeclear).base_access.should == 'read-write'
      access_types.bit(:writeset).base_access.should == 'read-write'
      access_types.bit(:writesetreadclear).base_access.should == 'read-write'
      access_types.bit(:writeclearreadset).base_access.should == 'read-write'
      access_types.bit(:write1toclear).base_access.should == 'read-write'
      access_types.bit(:write1toset).base_access.should == 'read-write'
      access_types.bit(:write0toclear).base_access.should == 'read-write'
      access_types.bit(:write0toset).base_access.should == 'read-write'
      access_types.bit(:write0totoggle).base_access.should == 'read-write'
      access_types.bit(:write1tosetreadclear).base_access.should == 'read-write'
      access_types.bit(:write1toclearreadset).base_access.should == 'read-write'
      access_types.bit(:write0tosetreadclear).base_access.should == 'read-write'
      access_types.bit(:writeonly).base_access.should == 'write-only'
      access_types.bit(:writeonlyclear).base_access.should == 'write-only'
      access_types.bit(:writeonlyreadzero).base_access.should == 'write-only'
      access_types.bit(:writeonlyset).base_access.should == 'write-only'
      access_types.bit(:writeonce).base_access.should == 'read-writeOnce'
      access_types.bit(:writeonlyonce).base_access.should == 'writeOnce'
      access_types.bit(:readwritenocheck).base_access.should == 'read-write'
      access_types.bit(:readonlyclearafter).base_access.should == 'read-only'
      # Checks are not exhaustive here, but check readable?/writable?
      access_types.bit(:readonly).readable?.should == true
      access_types.bit(:readonly).writable?.should == false
      access_types.bit(:writeonly).readable?.should == false
      access_types.bit(:writeonly).writable?.should == true
      access_types.bit(:readonlyclearafter).writable?.should == false
      access_types.bit(:writeonlyclear).readable?.should == false
      access_types.bit(:writeonlyset).readable?.should == false
      access_types.bit(:writeonlyonce).readable?.should == false
      access_types.bit(:readwrite).readable?.should == true
      access_types.bit(:readwrite).writable?.should == true
      access_types.bit(:writeonce).readable?.should == true
      access_types.bit(:readclear).writable?.should == false
      access_types.bit(:readset).writable?.should == false
      access_types.bit(:readonlyclearafter).writable?.should == false
      # Check exhaustive here, but check w1c for a few types
      access_types.bit(:write1toclear).w1c.should == true
      access_types.bit(:writeonly).w1c.should == false
      access_types.bit(:write0totoggle).w1c.should == false
      # Can't check set_only or clr_only, as those are attr_writers (no read query)
      # access_types.bit(:readwrite).set_only.should == false
      # access_types.bit(:readwrite).clr_only.should == false
      # access_types.bit(:writeset).set_only.should == true
      # access_types.bit(:writeclear).clr_only.should == true
      # Check read_action for all types
      # Check mod_write_value for all types
    end
  end
end
