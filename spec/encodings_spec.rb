# encoding: utf-8
require 'spec_helper'

describe 'Format Encodings' do
  it 'should show users the encoding formats available' do
    Origen::ENCODINGS.keys.should == [:utf8]
  end
  it 'should show users the keys for a particular format' do
    Origen::ENCODINGS[:utf8].keys[1..3].should == [:cent_sign, :pound_sign, :currency_sign]
  end
  #it 'should show users how to search for an encoded symbol and convert to a String' do
  #  encoding_search(/deg/).should == "°"
  #  encoding_search(/latin/).first.should == [:latin_capital_letter_a_with_grave, "À"]
  #  encoding_search(:latin_capital_letter_eth).should == "Ð"
  #end
end
