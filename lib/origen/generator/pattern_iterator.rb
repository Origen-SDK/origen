module Origen
  class Generator
    class PatternIterator
      attr_accessor :key

      def invoke(options, &block)
        if enabled?(options)
          @loop.call(options[key], &block)
        else
          yield
        end
      end

      def loop(&block)
        @loop = block
      end

      def setup(&block)
        if block
          @setup = block
        elsif @setup
          @setup
        # Setup is optional for an iterator, return something to keep the caller happy
        else
          ->(arg) { arg }
        end
      end

      def startup(&block)
        if block
          @startup = block
        elsif @startup
          @startup
        # Startup is optional for an iterator, return something to keep the caller happy
        else
          ->(_options, arg) { arg }
        end
      end

      def pattern_name(&block)
        if block
          @pattern_name = block
        elsif @pattern_name
          @pattern_name
        else
          fail "pattern_name must be defined for iterator: #{key}"
        end
      end

      def enabled?(options)
        options.keys.include?(key)
      end
    end
  end
end
