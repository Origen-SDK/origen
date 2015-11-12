require 'spec_helper'

describe Numeric do

  specify "unit helpers work" do
    10.V.should == 10
    10.v.should == 10
    10.s.should == 10
    10.S.should == 10
    10.a.should == 10
    10.A.should == 10
    10.mV.should == 10 / 1000.0
    10.mv.should == 10 / 1000.0
    10.ms.should == 10 / 1000.0
    10.mS.should == 10 / 1000.0
    10.ma.should == 10 / 1000.0
    10.mA.should == 10 / 1000.0
    10.uV.should == 10 / 1000_000.0
    10.uv.should == 10 / 1000_000.0
    10.us.should == 10 / 1000_000.0
    10.uS.should == 10 / 1000_000.0
    10.ua.should == 10 / 1000_000.0
    10.uA.should == 10 / 1000_000.0
    10.nV.should == 10 / 1000_000_000.0
    10.nv.should == 10 / 1000_000_000.0
    10.ns.should == 10 / 1000_000_000.0
    10.nS.should == 10 / 1000_000_000.0
    10.na.should == 10 / 1000_000_000.0
    10.nA.should == 10 / 1000_000_000.0
  end

  specify "numeric bit operations work" do
    0x400F7F.to_bitstring(32).should == '00000000010000000000111101111111'
    0x400F7F.to_bitstring(16).should == '10000000000111101111111'
    0x400F7F.to_bitstring(4).should == '10000000000111101111111'
    0x400F7F.reverse_bits(32).should == 0xFEF00200
    0x400F7F.reverse_bits(32).to_bitstring(32).should  == '11111110111100000000001000000000'
  end

  specify "byte conversions work" do
    1024.to_kB.should == 1
    1090.to_kB.round(3).should == 1.064
    (1024*1024).to_MB.should == 1
    (1024*1024*1024).to_MB.should == 1024
    (1024*1024*1024).to_GB.should == 1
    1024.kB.should == 1024 * 1024
    1.MB.should == 1024 * 1024
    1.GB.should == 1024 * 1024 * 1024
  end

  specify 'sized numbers work' do
    0x1234.sized(16).size.should == 16
    0x5.sized(8).to_bin.should == "0b00000101"
    0x5.sized(8).to_hex.should == "0x05"
    0x5.sized(16).to_hex.should == "0x0005"
    0x1234.sized(8).should == 0x34
  end

end
