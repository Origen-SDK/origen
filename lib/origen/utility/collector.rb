module Origen
  module Utility
    class Collector
      attr_reader :store

      def initialize
        @store = {}
      end

      def method_missing(method, *args, &_block)
        @store[method.to_s.sub('=', '').to_sym] = args.first
      end
    end
  end
end
