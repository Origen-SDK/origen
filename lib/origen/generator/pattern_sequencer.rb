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
            blocked = false
            until completed
              # If already acquired or available
              if (thread.reservations[id] && thread.reservations[id][:semaphore]) || s.try_acquire
                thread.record_active if blocked
                yield
                completed = true
              else
                thread.waiting_for_serialize(id, blocked)
                blocked = true
              end
            end
            # If the thread has reserved access to this serialized resource then don't release it now, but
            # store a reference to the semaphore and it will be released at the end of the reserve block
            if thread.reservations[id]
              thread.reservations[id][:semaphore] = s
            else
              s.release
            end
          else
            yield
          end
        end

        # Once a lock is acquired on a serialize block with the given ID, it won't be released to
        # other parallel threads until the end of this block
        def reserve(id)
          if active?
            if thread.reservations[id]
              thread.reservations[id][:count] += 1
            else
              thread.reservations[id] = { count: 1, semaphore: nil }
            end
            yield
            if thread.reservations[id][:count] == 1
              # May not be set if the application reserved the resource but never hit it
              if s = thread.reservations[id][:semaphore]
                s.release
              end
              thread.reservations[id] = nil
            else
              thread.reservations[id][:count] -= 1
            end
          else
            yield
          end
        end

        # Returns true if a pattern sequence is currently open/active
        def active?
          !!@active
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

        def active=(val)
          @active = val
        end

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
