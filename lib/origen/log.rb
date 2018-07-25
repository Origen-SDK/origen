module Origen
  # An instance of this class is instantiated as Origen.log and provides the following API
  #
  # @example
  #   log.error "Blah"     # Error message, always shown
  #   log.debug "Blah"     # Debug message, only shown when in verbose mode
  #   log.info  "Blah"     # Info message, always shown
  #   log.warn  "Blah"     # Warning message, always shown
  #   log.deprecate "Blah" # Deprecate message, always shown
  class Log
    require 'colored'
    require 'logger'

    LEVELS = [:normal, :verbose, :silent]

    def initialize
      @log_time_0 = @t0 = Time.new
      self.level = :normal
    end

    def console_only?
      self.class.console_only? || !Origen.app || Origen.running_globally?
    end

    # Anything executed within the given block will log to the console only
    #
    # @example
    #
    #   Origen::Log.console_only do
    #     Origen.log.info "This will not appear in the log file!"
    #   end
    def self.console_only
      @console_only = true
      yield
      @console_only = false
    end

    def self.console_only=(val)
      @console_only = val
    end

    def self.console_only?
      @console_only
    end

    # Set the logger level, for valid values see LEVELS
    def level=(val)
      unless LEVELS.include?(val)
        fail "Unknown log level, valid values are: #{LEVELS}"
      end
      # Map the log4r levels to our simplified 3 level system
      # log4r level order is DEBUG < INFO < WARN < ERROR < FATAL
      case val
      when :normal
        # Output everything except debug statements
        console.level = Logger::INFO
        # Output everything
        log_files(:level=, Logger::DEBUG) unless console_only?
      when :verbose
        console.level = Logger::DEBUG
        log_files(:level=, Logger::DEBUG) unless console_only?
      when :silent
        # We don't use any fatal messages, so this is effectively OFF
        console.level = Logger::FATAL
        log_files(:level=, Logger::DEBUG) unless console_only?
      end

      @level = val
    end

    # Returns the current logger level
    def level
      @level
    end

    def validate_args(string, msg_type)
      return string, msg_type unless string.is_a? Symbol
      ['', string]
    end

    def debug(string = '', msg_type = nil)
      string, msg_type = validate_args(string, msg_type)
      msg = format_msg('DEBUG', string)
      log_files(:debug, msg) unless console_only?
      console.debug msg
      nil
    end

    def info(string = '', msg_type = nil)
      string, msg_type = validate_args(string, msg_type)
      msg = format_msg('INFO', string)
      log_files(:info, msg) unless console_only?
      console.info msg
      nil
    end
    # Legacy methods
    alias_method :lputs, :info
    alias_method :lprint, :info

    def success(string = '', msg_type = nil)
      string, msg_type = validate_args(string, msg_type)
      msg = format_msg('SUCCESS', string)
      log_files(:info, msg) unless console_only?
      console.info color_unless_remote(msg, :green)
      nil
    end

    def deprecate(string = '', msg_type = nil)
      string, msg_type = validate_args(string, msg_type)
      msg = format_msg('DEPRECATED', string)
      log_files(:warn, msg) unless console_only?
      console.warn color_unless_remote(msg, :yellow)
      nil
    end
    alias_method :deprecated, :deprecate

    def warn(string = '', msg_type = nil)
      string, msg_type = validate_args(string, msg_type)
      msg = format_msg('WARNING', string)
      log_files(:warn, msg) unless console_only?
      console.warn color_unless_remote(msg, :yellow)
      nil
    end
    alias_method :warning, :warn

    def error(string = '', msg_type = nil)
      string, msg_type = validate_args(string, msg_type)
      msg = format_msg('ERROR', string)
      log_files(:error, msg) unless console_only?
      console.error color_unless_remote(msg, :red)
      nil
    end

    # Made these all class methods so that they can be read without
    # instantiating a new logger (mainly for use by the origen save command)
    def self.log_file
      File.join(log_file_directory, 'last.txt')
    end

    def self.log_file_directory
      @log_file_directory ||= begin
        dir = Origen.config.log_directory
        FileUtils.mkdir_p dir unless File.exist?(dir)
        dir
      end
    end

    def silent?
      level == :silent
    end

    def verbose?
      level == :verbose
    end

    # Force logger to write any buffered output
    def flush
      # No such API provided by the underlying logger, method kept around for compatibility with application
      # code which was built for a previous version of this logger where flushing was required
    end

    # Mainly intended for testing the logger, this will return the log level to the default (:normal)
    # and close all log files, such that any further logging will be done to a new file(s)
    def reset
      self.level = :normal
      @last_file.close if @last_file
      @last_file = nil
      @job_file.close if @job_file
      @job_file = nil
    end

    # @api private
    def start_job(name, type)
      dir = File.join(Origen.config.log_directory, type.to_s)
      if target = Origen.try(:target).try(:name)
        dir = File.join(dir, target)
      end
      if env = Origen.try(:environment).try(:name)
        dir = File.join(dir, env)
      end
      FileUtils.mkdir_p dir unless File.exist?(dir)
      @job_file_path = File.join(dir, "#{name}.txt")
      FileUtils.rm_f(@job_file_path) if File.exist?(@job_file_path)
      @job_file = open_log(@job_file_path)
    end

    # @api private
    def stop_job
      if @job_file
        Origen.log.info "Log file written to: #{@job_file_path}"
        @job_file.close
        @job_file = nil
      end
    end

    private

    # When running on an LSF client, the console log output is captured to a file. Color codings in files just
    # add noise, so inhibit them in this case since it is not providing any visual benefit to the user
    def color_unless_remote(msg, color)
      if Origen.running_remotely?
        msg
      else
        msg.send(color)
      end
    end

    # Returns a logger instance that will send to the console
    def console
      @console ||= open_log(STDOUT)
    end

    # Returns a logger instance that will send to the log/last.txt file
    def last_file
      @last_file ||= begin
        # Preserve one prior version of the log file
        FileUtils.mv Log.log_file, "#{Log.log_file}.old" if File.exist?(Log.log_file)
        open_log(Log.log_file)
      end
    end

    # Sends the given method and arguments to all file logger instances
    def log_files(method, *args)
      # When running remotely on an LSF client, the LSF manager will capture STDOUT (i.e. the console log output)
      # and save it to a log file.
      # Don't write to the last log file in that case because we would have multiple processes all vying to
      # write to it at the same time.
      last_file.send(method, *args) unless Origen.running_remotely?
      @job_file.send(method, *args) if @job_file
    end

    def open_log(file)
      l = Logger.new(file)
      l.formatter = proc do |severity, dateime, progname, msg|
        msg
      end
      l
    end

    def relog(msg)
      if msg =~ /^\[(\w+)\] .*/
        method = Regexp.last_match(1).downcase
        if respond_to?(method)
          send method, msg.sub(/.*\|\|\s*/, '')
        else
          info msg
        end
      else
        info msg
      end
    end

    def format_msg(type, msg)
      log_time_1 = Time.new
      delta_t = (log_time_1.to_f - @log_time_0.to_f).round(6)
      delta_t = '%0.3f' % delta_t
      delta_t0 = (log_time_1.to_f - @t0.to_f).round(6)
      delta_t0 = '%0.3f' % delta_t0
      msg = "[#{type}]".ljust(13) + "#{delta_t0}[#{delta_t}]".ljust(16) + "|| #{msg}\n"
      @log_time_0 = log_time_1
      msg
    end
  end
end
