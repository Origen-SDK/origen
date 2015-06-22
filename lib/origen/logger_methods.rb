module Origen
  module LoggerMethods
    extend ActiveSupport::Concern

    included do |klass|
      Origen.deprecate <<-END
The LoggerMethods module is deprecated, use Origen.log instead (or just
log from within a class that includes Origen::Model). See here for the new API:
http://origen.freescale.net/origen/latest/guides/utilities/logger/
Called from the #{klass} class.
END
    end

    def log
      @log ||= Origen.log
    end

    def lputs(*args)
      Origen.log.lputs(*args)
    end
    alias_method :lprint, :lputs

    def warn(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      args.each { |arg| Origen.log.warn arg }
    end
    alias_method :warning, :warn

    def error(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      args.each { |arg| Origen.log.error arg }
    end

    def alert(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      args.each { |arg| Origen.log.warn arg }
    end

    def deprecated(*lines)
      options = lines.last.is_a?(Hash) ? lines.pop : {}
      lines.flatten.each do |line|
        line.split(/\n/).each do |line|
          Origen.log.deprecate line
        end
      end
    end

    def highlight
      lputs ''
      lputs '######################################################################'
      yield
      lputs '######################################################################'
      lputs ''
    end
  end
end
