module Origen
  # Provides methods to detect the operating system used at runtime, an instance of
  # this class is automatically instantiated as Origen.os.
  #
  # @example
  #   Origen.os.windows?   # => false
  #   Origen.os.linux?     # => true
  class OperatingSystems
    def windows?
      !!(RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/)
    end

    def mac?
      !!(RUBY_PLATFORM =~ /darwin/)
    end

    def linux?
      !windows? && !mac?
    end

    def unix?
      !windows?
    end
  end

  # Blow this cache whenever this file is re-loaded
  @operating_systems = nil

  def self.os
    @operating_systems ||= OperatingSystems.new
  end
end
