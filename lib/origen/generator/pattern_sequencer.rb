require 'concurrent'
module Origen
  class Generator
    # Provides APIs to enable applications to support concurrency
    class PatternSequencer
      class << self
        def serialize(id = nil)
          if active?
            s = nil
            id ||= caller[0]
            @semaphores ||= {}
            @semaphores[id] ||= Concurrent::Semaphore.new(1)
            s = @semaphores[id]
            completed = false
            until completed
              if s.try_acquire
                yield
                completed = true
              else
                thread.waiting_for_serialize(id)
              end
            end
            s.release
          else
            yield
          end
        end

        # Returns true if a pattern sequence is currently open/active
        def active?
          true
        end
        alias_method :open?, :active?
        alias_method :runnng?, :active?

        # Returns true if called from the main thread
        # def primary?
        #  !sequence_active? || !thread || thread.primary?
        # end

        # Returns the PatternThread object for the current thread
        def thread
          @thread.value
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
PatSeq.send(:thread=, nil)
