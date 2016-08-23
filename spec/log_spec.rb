require 'spec_helper.rb'

describe 'Check that the msg_hash in Origen.log stores messages correctly' do
  attr_accessor :msg_type
  @msg_type = [:info, :warn, :error,  :deprecate, :debug, :success]
  @msg_type.each do |m|
    it "Will check that the msg_hash[:#{m}] updates correctly for default message type" do
      initial_count = {}
      type = [:info, :warn, :error,  :deprecate, :debug, :success]
      type.each do |k|
        initial_count[k] = Origen.log.msg_hash[k][nil].size
      end
      Origen.log.send(m, 'Test message')
      Origen.log.msg_hash[m][nil].last.include?(m.to_s.upcase).should == true
      type.each do |k|
        if k == m
          Origen.log.msg_hash[k][nil].size.should == initial_count[k] + 1
        else
          Origen.log.msg_hash[k][nil].size.should == initial_count[k]
        end
      end
    end
  end

  @msg_type.each do |m|
    it "Will check that the #{m} can handle nil for both msg and msg_type" do
      initial_count = {}
      type = [:info, :warn, :error,  :deprecate, :debug, :success]
      type.each do |k|
        initial_count[k] = Origen.log.msg_hash[k][nil].size
      end
      Origen.log.send(m)
      Origen.log.msg_hash[m][nil].last.include?(m.to_s.upcase).should == true
      Origen.log.msg_hash[m][nil].last[-8..-1].should == ']    || '
      type.each do |k|
        if k == m
          Origen.log.msg_hash[k][nil].size.should == initial_count[k] + 1
        else
          Origen.log.msg_hash[k][nil].size.should == initial_count[k]
        end
      end
    end
  end
  
  @msg_type.each do |m|
    it "Will check that the #{m} can handle nil for msg and msg_type set with a symbol.  Padding example" do
      initial_count = Hash.new do |h, k|
        h[k]= {}
      end
      type = [:info, :warn, :error,  :deprecate, :debug, :success]
      type.each do |k|
        [nil, :check2].each do |k1|
          initial_count[k][k1] = Origen.log.msg_hash[k][k1].size
        end
      end
      Origen.log.send(m, :check2)
      Origen.log.msg_hash[m][:check2].last.include?(m.to_s.upcase).should == true
      Origen.log.msg_hash[m][:check2].last[-8..-1].should == ']    || '
      type.each do |k|
        if k == m
          Origen.log.msg_hash[k][nil].size.should == initial_count[k][nil]
          Origen.log.msg_hash[k][:check2].size.should == initial_count[k][:check2] + 1
        else
          Origen.log.msg_hash[k][nil].size.should == initial_count[k][nil]
          Origen.log.msg_hash[k][:check2].size.should == initial_count[k][:check2]
        end
      end
    end
  end
  
  @msg_type.each do |m|
    it "Will check that the msg_hash[:#{m}] for a non-default size is nil if not set" do
      initial_count = {}
      type = [:info, :warn, :error,  :deprecate, :debug, :success]
      type.each do |k|
        Origen.log.msg_hash[k][:section3].nil? == true
      end
    end
  end

  
  @msg_type.each do |m|
    it "Will check that the msg_hash[:#{m}] updates correctly for section message code" do
      initial_count = {}
      type = [:info, :warn, :error,  :deprecate, :debug, :success]
      type.each do |k|
        initial_count[k] = Origen.log.msg_hash[k][:section1].size
      end
      Origen.log.send(m, 'Test message', :section1)
      Origen.log.msg_hash[m][:section1].last.include?(m.to_s.upcase).should == true
      type.each do |k|
        if k == m
          Origen.log.msg_hash[k][:section1].size.should == initial_count[k] + 1
        else
          Origen.log.msg_hash[k][:section1].size.should == initial_count[k]
        end
      end
      type.each do |k|
        Origen.log.msg_hash[k][:section3].nil? == true
      end
    end
  end

  
  
end