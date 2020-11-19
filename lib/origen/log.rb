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
      @custom_logs = {}
      @interceptors = {}
    end

    def console_only?(options = {})
      if options.key?(:console_only)
        option = options[:console_only]
      else
        option = self.class.console_only?
      end
      option || !Origen.app || Origen.running_globally?
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

    # @api private
    #
    # @example of an interceptor:
    #
    #     # An interceptor ID is returned, this should be given to stop_intercepting
    #     @log_intercept_id = Origen.log.start_intercepting do |msg, type, options, original|
    #       if some_condition_is_true?
    #         # Handling it ourselves
    #         my_method(msg, type)
    #       else
    #         # Call the original Origen.log method (or the next interceptor in line)
    #         original.call(msg, type, options)
    #       end
    #     end
    def start_intercepting(&block)
      id = block.object_id
      @interceptors[id] = block
      id
    end

    # @api private
    def stop_intercepting(id)
      @interceptors.delete(id)
    end

    def debug(string = '', options = {})
      string, options = sanitize_args(string, options)
      PatSeq.add_thread(string) unless options[:no_thread_id]
      intercept(string, :debug, options) do |msg, type, options|
        msg = format_msg('DEBUG', msg)
        log_files(:debug, msg) unless console_only?(options)
        console.debug msg
        nil
      end
    end

    def info(string = '', options = {})
      string, options = sanitize_args(string, options)
      PatSeq.add_thread(string) unless options[:no_thread_id]
      intercept(string, :info, options) do |msg, type, options|
        msg = format_msg('INFO', msg)
        log_files(:info, msg) unless console_only?(options)
        console.info msg
        nil
      end
    end
    # Legacy methods
    alias_method :lputs, :info
    alias_method :lprint, :info

    def success(string = '', options = {})
      string, options = sanitize_args(string, options)
      PatSeq.add_thread(string) unless options[:no_thread_id]
      intercept(string, :success, options) do |msg, type, options|
        msg = format_msg('SUCCESS', msg)
        log_files(:info, msg) unless console_only?(options)
        console.info color_unless_remote(msg, :green)
        nil
      end
    end

    def deprecate(string = '', options = {})
      string, options = sanitize_args(string, options)
      PatSeq.add_thread(string) unless options[:no_thread_id]
      intercept(string, :deprecate, options) do |msg, type, options|
        msg = format_msg('DEPRECATED', msg)
        log_files(:warn, msg) unless console_only?(options)
        console.warn color_unless_remote(msg, :yellow)
        nil
      end
    end
    alias_method :deprecated, :deprecate

    def warn(string = '', options = {})
      string, options = sanitize_args(string, options)
      PatSeq.add_thread(string) unless options[:no_thread_id]
      intercept(string, :warn, options) do |msg, type, options|
        msg = format_msg('WARNING', msg)
        log_files(:warn, msg) unless console_only?(options)
        console.warn color_unless_remote(msg, :yellow)
        nil
      end
    end
    alias_method :warning, :warn

    def error(string = '', options = {})
      string, options = sanitize_args(string, options)
      PatSeq.add_thread(string) unless options[:no_thread_id]
      intercept(string, :error, options) do |msg, type, options|
        msg = format_msg('ERROR', msg)
        log_files(:error, msg) unless console_only?(options)
        console.error color_unless_remote(msg, :red)
        nil
      end
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

    # Force the logger to write any buffered output to the log files
    def flush
      @open_logs.each do |logger, file|
        file.flush
      end
      nil
    end

    # Mainly intended for testing the logger, this will return the log level to the default (:normal)
    # and close all log files, such that any further logging will be done to a new file(s)
    def reset
      self.level = :normal
      flush
      close_log(@last_file)
      @last_file = nil
      close_log(@job_file)
      @job_file = nil
      @custom_logs.each do |name, log|
        close_log(log)
      end
      @custom_logs = {}
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
      @@job_file_paths = {} unless defined?(@@job_file_paths)
      # Make sure the log name is unique in this run, duplication and overwrite can occur in cases where
      # a pattern is run multiple times during a simulation
      @job_file_path = File.join(dir, "#{name}.txt")
      if n = @@job_file_paths[@job_file_path]
        @@job_file_paths[@job_file_path] += 1
        @job_file_path = File.join(dir, "#{name}_#{n}.txt")
      else
        @@job_file_paths[@job_file_path] = 1
      end
      FileUtils.rm_f(@job_file_path) if File.exist?(@job_file_path)
      @job_file = open_log(@job_file_path)
    end

    # @api private
    def stop_job
      if @job_file
        if tester && tester.respond_to?(:log_file_written)
          tester.log_file_written @job_file_path
        else
          Origen.log.info "Log file written to: #{@job_file_path}"
        end
        flush
        close_log(@job_file)
        @job_file = nil
      end
    end

    def method_missing(method, *args, &block)
      @custom_logs[method.to_sym] ||= begin
        log_file = File.join(Log.log_file_directory, "#{method}.txt")
        unless Origen.running_remotely?
          FileUtils.mv log_file, "#{log_file}.old" if File.exist?(log_file)
        end
        open_log(log_file)
      end
      msg = args.shift
      options = args.shift || {}
      if options.key?(:format) && !options[:format]
        msg = "#{msg}\n"
      else
        msg = format_msg(method.to_s.upcase, msg)
      end
      console.info msg if options[:verbose]
      @custom_logs[method.to_sym].info(msg)
    end

    private

    def intercept(msg, type, options, &block)
      if @interceptors.size > 0
        call_interceptor(@interceptors.values, msg, type, options, &block)
      else
        yield(msg, type, options)
      end
    end

    def call_interceptor(interceptors, msg, type, options, &original)
      interceptor = interceptors.shift
      if interceptors.empty?
        func = -> (msg, type, options) { original.call(msg, type, options) }
      else
        func = -> (msg, type, options) { call_interceptor(interceptors, msg, type, options, &original) }
      end
      interceptor.call(msg, type, options, func)
    end

    def sanitize_args(*args)
      message = ''
      options = {}
      args.each do |arg|
        if arg.is_a?(String)
          message = arg
        elsif arg.is_a?(Hash)
          options = arg
        end
      end
      [message, options]
    end

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
      @open_logs ||= {}
      unless file.class == IO
        file = File.open(file, 'w+')
      end
      l = Logger.new(file)
      l.formatter = proc do |severity, dateime, progname, msg|
        msg
      end
      @open_logs[l] = file
      l
    end

    def close_log(logger)
      if logger
        @open_logs.delete(logger)
        logger.close
      end
    end

    def relog(msg, options = {})
      if options[:log_file]
        send options[:log_file], msg.sub(/.*\|\|\s*/, ''), options
      elsif msg =~ /^\[(\w+)\] .*/
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
