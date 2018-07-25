require 'spec_helper.rb'

describe 'The Origen logger' do

  MSG_TYPES = [:info, :warn, :error,  :deprecate, :debug, :success]

  before :each do
    Origen.log.reset
  end

  it "Will output everything except debug messages to the console by default" do
    MSG_TYPES.each do |m|
      if m == :debug
        expect { Origen.log.send(m, 'Test message 1') }.to_not output(/.*#{m.to_s.upcase}.*Test message.*/).to_stdout_from_any_process
      else
        expect { Origen.log.send(m, 'Test message 1') }.to output(/.*#{m.to_s.upcase}.*Test message.*/).to_stdout_from_any_process
      end
    end
  end

  it "Will output everything to the console when level is set to verbose" do
    Origen.log.level = :verbose

    MSG_TYPES.each do |m|
      expect { Origen.log.send(m, 'Test message 2') }.to output(/.*#{m.to_s.upcase}.*Test message.*/).to_stdout_from_any_process
    end
  end

  it "Will output nothing to the console when level is set to silent" do
    Origen.log.level = :silent

    MSG_TYPES.each do |m|
      expect { Origen.log.send(m, 'Test message 3') }.to_not output(/.*#{m.to_s.upcase}.*Test message.*/).to_stdout_from_any_process
    end
  end

  it "Will output everything to log/last.txt by default" do
    MSG_TYPES.each do |m|
      Origen.log.send(m, 'Test message 4')
      Origen.log.send(:reset)  # Force a flush of the file buffer by closing the log
      File.read(File.join("log", "last.txt")).should include(m.to_s.upcase, "Test message")
    end
  end

  it "Will output everything to log/last.txt when level is set to verbose" do
    Origen.log.level = :verbose

    MSG_TYPES.each do |m|
      Origen.log.send(m, 'Test message 5')
      Origen.log.send(:reset)  # Force a flush of the file buffer by closing the log
      File.read(File.join("log", "last.txt")).should include(m.to_s.upcase, "Test message")
    end
  end

  it "Will output everything to log/last.txt when level is set to silent" do
    Origen.log.level = :silent

    MSG_TYPES.each do |m|
      Origen.log.send(m, 'Test message 6')
      Origen.log.send(:reset)  # Force a flush of the file buffer by closing the log
      File.read(File.join("log", "last.txt")).should include(m.to_s.upcase, "Test message")
    end
  end

  it "Can handle nil for the msg" do
    Origen.log.level = :verbose

    MSG_TYPES.each do |m|
      expect { Origen.log.send(m) }.to output(/.*#{m.to_s.upcase}.* \|\| $/).to_stdout_from_any_process
    end
  end

  it "Interprets a single symbol arg as a nil message (legacy API compatibility)" do
    Origen.log.level = :verbose

    MSG_TYPES.each do |m|
      expect { Origen.log.send(m, :blah) }.to output(/.*#{m.to_s.upcase}.* \|\| $/).to_stdout_from_any_process
    end

  end
end
