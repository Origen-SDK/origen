# General Origen.app.specs

require 'spec_helper'

describe Origen::Application do
  describe "Failing the application" do
    it 'Raises a RuntimeError, showing a default fail message of the application name, when Origen.app.fail is used' do
      expect {
        Origen.app.fail
      }.to raise_error RuntimeError, "Fail in origen_core"
    end

    it 'Raises a RuntimeError, prepending the application name, when Origen.app.fail is used with a :message option' do
      expect {
        Origen.app.fail(message: "Bye!")
      }.to raise_error RuntimeError, "Fail in origen_core: Bye!"
    end

    it 'Raises the given exception when :exception_class is used' do
      expect {
        Origen.app.fail(message: "Bye from OrigenError!", exception_class: Origen::OrigenError)
      }.to raise_error Origen::OrigenError, "Fail in origen_core: Bye from OrigenError!"
    end

    it 'Exits the application when Origen.app.fail! is used without debug enabled. Exit status is 1' do
      expect(Origen.debugger_enabled?).to be false
      expect {
        Origen.app.fail!
      }.to raise_error { |e| 
        expect(e).to be_a(SystemExit)
        expect(e.status).to eql(1)
      }

      # Check the logger for some default output
      expect(Origen.log.msg_hash[:error][nil][-1]).to include("Fail in origen_core")
    end

    it 'Logs the output error using the logger when Origen.app.fail! is used without debug enabled' do
      expect(Origen.debugger_enabled?).to be false
      expect {
        Origen.app.fail!(message: "Bye from fail!")
      }.to raise_error SystemExit

      # Check the logger
      expect(Origen.log.msg_hash[:error][nil][-1]).to include("Fail in origen_core: Bye from fail!")
    end

    it 'Can throw a custom exit status when :exit_status is given to Origen.app.fail! without debug enabled' do
      expect {
        Origen.app.fail!(exit_status: 2)
      }.to raise_error { |e| 
        expect(e).to be_a(SystemExit)
        expect(e.status).to eql(2)
      }
    end

    it 'Raises an exception, showing the stack trace, when Origen.app.fail! is used with debug enabled' do
      Origen.instance_variable_set(:@debug, true)
      expect(Origen.debugger_enabled?).to be true
      expect {
        Origen.app.fail!(message: "Bye from fail with debugger!")
      }.to raise_error RuntimeError, "Fail in origen_core: Bye from fail with debugger!"

      # Check for logger output. Should be no logger errors here from the last fail! call.
      unless Origen.log.msg_hash[:error][nil][-1].nil?
        # if the logged errors are empty, then obvisouly nothing was added. If not, check that the last message wasn't from fail!
        expect(Origen.log.msg_hash[:error][nil][-1]).to_not include("Bye from fail with debugger!")
      end

      Origen.instance_variable_set(:@debug, false)
      expect(Origen.debugger_enabled?).to be false
    end

    it 'Does not include the backtrace for the #fail! call to #fail when debug is enabled' do
      Origen.instance_variable_set(:@debug, true)
      expect(Origen.debugger_enabled?).to be true
      expect {
        Origen.app.fail!(message: "Bye from fail with debugger!")
      }.to raise_error { |e|
        expect(e).to be_a(RuntimeError)
        expect(e.message).to include("Fail in origen_core: Bye from fail with debugger!")
        expect(e.backtrace[0]).to_not include("in `fail!'")
      }

      Origen.instance_variable_set(:@debug, false)
      expect(Origen.debugger_enabled?).to be false
    end

  end
end