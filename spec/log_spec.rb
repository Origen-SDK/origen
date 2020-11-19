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

  it "Accepts a symbol as a 2nd arg (legacy API compatibility)" do
    Origen.log.level = :verbose

    MSG_TYPES.each do |m|
      expect { Origen.log.send(m, 'Test message 7', :blah) }.to output(/.*#{m.to_s.upcase}.*Test message.*/).to_stdout_from_any_process
    end
  end

  it "Output can be logged to the console only" do
    Origen.log.send(:reset)  # Force a flush of the file buffer by closing the log
    Origen.log.level = :verbose
    expect { Origen.log.debug 'Test message 8' }.to output(/.*DEBUG.*Test message 8.*/).to_stdout_from_any_process
    Origen.log.send(:reset)  # Force a flush of the file buffer by closing the log
    File.read(File.join("log", "last.txt")).should include("DEBUG", "Test message 8")

    Origen.log.send(:reset)  # Force a flush of the file buffer by closing the log
    Origen.log.level = :verbose
    Origen::Log.console_only do
      expect { Origen.log.debug 'Test message 9' }.to output(/.*DEBUG.*Test message 9.*/).to_stdout_from_any_process
    end
    Origen.log.send(:reset)  # Force a flush of the file buffer by closing the log
    File.read(File.join("log", "last.txt")).should_not include("DEBUG", "Test message 9")

    Origen.log.send(:reset)  # Force a flush of the file buffer by closing the log
    Origen.log.level = :verbose
    expect { Origen.log.debug 'Test message 10', console_only: true }.to output(/.*DEBUG.*Test message 10.*/).to_stdout_from_any_process
    Origen.log.send(:reset)  # Force a flush of the file buffer by closing the log
    File.read(File.join("log", "last.txt")).should_not include("DEBUG", "Test message 10")
  end

  it "Can log to a custom log file" do
    Origen.log.reset
    Origen.log.blah 'Test message 11'
    Origen.log.flush
    File.read(File.join("log", "blah.txt")).should include("BLAH", "Test message 11")
    Origen.log.reset
    Origen.log.blah 'Test message 12', format: false
    Origen.log.flush
    File.read(File.join("log", "blah.txt")).should_not include("BLAH")
    File.read(File.join("log", "blah.txt")).should include("Test message 12")
    Origen.log.reset
    expect { Origen.log.bond 'Test message 007', verbose: true }.to output(/.*BOND.*Test message 007.*/).to_stdout_from_any_process
  end
end
