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
    require 'log4r'
    require 'log4r/outputter/fileoutputter'

    LEVELS = [:normal, :verbose, :silent]

    def initialize
      @log_time_0 = @t0 = Time.new
      self.level = :normal
    end

    def console_only?
      self.class.console_only? || !Origen.app
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
        console.level = Log4r::INFO
        # Output everything
        log_files.level = Log4r::DEBUG unless console_only?
      when :verbose
        console.level = Log4r::DEBUG
        log_files.level = Log4r::DEBUG unless console_only?
      when :silent
        # We don't use any fatal messages, so this is effectively OFF
        console.level = Log4r::FATAL
        log_files.level = Log4r::DEBUG unless console_only?
      end

      @level = val
    end

    # Returns the current logger level
    def level
      @level
    end

    def debug(string = '')
      msg = format_msg('DEBUG', string)
      log_files.debug msg unless console_only?
      console.debug msg
      nil
    end

    def info(string = '')
      msg = format_msg('INFO', string)
      log_files.info msg unless console_only?
      console.info msg
      nil
    end
    # Legacy methods
    alias_method :lputs, :info
    alias_method :lprint, :info

    def success(string = '')
      msg = format_msg('SUCCESS', string)
      log_files.info msg unless console_only?
      console.info msg.green
      nil
    end

    def deprecate(string = '')
      msg = format_msg('DEPRECATED', string)
      log_files.warn msg unless console_only?
      console.warn msg.yellow
      nil
    end
    alias_method :deprecated, :deprecate

    def warn(string = '')
      msg = format_msg('WARNING', string)
      log_files.warn msg unless console_only?
      console.warn msg.yellow
      nil
    end
    alias_method :warning, :warn

    def error(string = '')
      msg = format_msg('ERROR', string)
      log_files.error msg unless console_only?
      console.error msg.red
      nil
    end

    # Made these all class methods so that they can be read without
    # instantiating a new logger (mainly for use by the origen save command)
    def self.log_file
      "#{log_file_directory}/last.txt"
    end

    def self.rolling_log_file
      "#{log_file_directory}/rolling.txt"
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
      if Origen.app
        log_files.outputters.each(&:flush)
      end
      console.outputters.each(&:flush)
    end

    private

    # Returns a Log4r instance that will send to the console
    def console
      @console ||= begin
        console = Log4r::Logger.new 'console'
        # console.level = QUIET
        out = Log4r::Outputter.stdout
        out.formatter = format
        console.outputters << out
        console
      end
    end

    # Returns a Log4r instance that will send to the log files
    def log_files
      @log_files ||= begin
        log_files = Log4r::Logger.new 'log_files'
        # log_files.level = QUIET
        file = Log4r::FileOutputter.new('fileOutputter', filename: self.class.log_file, trunc: true)
        file.formatter = format
        log_files.outputters << file
        unless Origen.running_remotely?
          rolling_file = Log4r::RollingFileOutputter.new('rollingfileOutputter', filename: self.class.rolling_log_file, trunc: false, maxsize: 5_242_880, max_backups: 10)
          rolling_file.formatter = format
          log_files.outputters << rolling_file
        end
        log_files
      end
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
      msg = "[#{type}]".ljust(13) + "#{delta_t0}[#{delta_t}]".ljust(16) + "|| #{msg}"
      @log_time_0 = log_time_1
      msg
    end

    def format
      Log4r::PatternFormatter.new(pattern: '%m')
    end
  end
end
