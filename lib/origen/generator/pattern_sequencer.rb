require 'concurrent'
module Origen
  class Generator
    class PatternSequencer
      class << self
        def serialize
          if sequence_active?
            # Just to make sure there are no races with creating the block specific semaphores
            s = nil
            with_semaphore do
              @semaphores ||= {}
              @semaphores[caller[0]] ||= Concurrent::Semaphore.new(1)
              s = @semaphores[caller[0]]
              s.acquire
            end
            yield
            s.release
          else
            yield
          end
        end

        # Returns true if a pattern sequence is currently open/active
        def sequence_active?
          true
        end

        # @api private
        def semaphore
          @semaphore ||= Concurrent::Semaphore.new(1)
        end

        # @api private
        def with_semaphore
          semaphore.acquire
          yield
          semaphore.release
        end
      end

      def initialize(name, main_body)
        @name = name
        @main_body = main_body
      end

      def run(pattern_name)
        pattern = Origen.generator.pattern_finder.find(pattern_name.to_s, {})
        pattern = pattern[:pattern] if pattern.is_a?(Hash)
        load pattern
      end

      def in_parallel
        threads << Thread.new do
          yield
        end
      end

      private

      def execute
        @main_body.call(self)
        threads.each(&:join)
      end

      def threads
        @threads ||= []
      end
    end
  end
end
PatSeq = Origen::Generator::PatternSequencer
PatSeq.semaphore  # Just to make sure there are no races to instantiate this later
