require 'concurrent'
module Origen
  class Generator
    # Provides APIs to enable applications to support concurrency
    class PatternSequencer
      class << self
        def serialize
          if active?
            s = nil
            # Just to make sure there are no races with creating the block specific semaphores
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
        def active?
          true
        end
        alias :open? :active?
        alias :runnng? :active?

        # Returns true if called from the main thread
        def primary?
          !sequence_active? || !thread || thread.primary?
        end

        # Returns the PatternThread object for the current thread
        def thread
          @thread.value
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

        private

        def thread=(t)
          @thread ||= Concurrent::ThreadLocalVar.new(nil)
          @thread.value = t
        end
      end
    end
  end
end
PatSeq = Origen::Generator::PatternSequencer
PatSeq.semaphore  # Just to make sure there are no races to instantiate this later
PatSeq.send(:thread=, nil)
