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
  
  specify "metric unit conversions work" do
    1.as_s.should == '1s'
    10.as_a.should == '10a'
    100.as_ohm.should == '100ohm'
    1_000.as_bps.should == '1.0kbps'
    10_100.as_ts.should == '10.1kts'
    12_000_000.as_Ohm.should == '12.0MOhm'
    123_000_000_000.as_Hz.should == '123.0GHz'
    123_456_000_000_000.as_hz.should == '123.456Thz'
    1.23e16.as_Ts.should == '12.3PTs'
    0.1.as_v.should == '100.0mv'
    0.001.as_V.should == '1.0mV'
    0.00002.as_A.should == '20.0uA'
    0.0000003.as_s.should == '300.0ns'
    0.000000000004.as_sps.should == '4.0psps'
    5.1e-14.as_units("parsec").should == '51.0aparsec'  # About 15.7cm
    6.12e-100.as_units("googol").should == '6.120e-100googol'  # 6.12
    1e20.as_units("hp").should == '100000.0Php'
    -10.as_units('[mV]').should == '-10[mV]'
  end
end
