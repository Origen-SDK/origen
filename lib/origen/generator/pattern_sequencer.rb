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

        # Returns the PatternThread object for the current thread
        def thread
          @thread.value
        end

        # Prepends the given string with "[<current thread ID>] " unless it already contains it
        def add_thread(str)
          if active? && thread
            id = "[#{thread.id}] "
            str.prepend(id) unless str =~ /#{id}/
          end
          str
        end

        # Wait for the given threads to complete. If no IDs given it will wait for all currently running
        # threads (except for the one who called this) to complete.
        def wait_for_threads_to_complete(*ids)
          @current_sequence.wait_for_threads_to_complete(*ids)
        end
        alias_method :wait_for_thread, :wait_for_threads_to_complete
        alias_method :wait_for_threads, :wait_for_threads_to_complete
        alias_method :wait_for_thread_to_complete, :wait_for_threads_to_complete

        def sync_up(*ids)
          if @current_sequence
            @current_sequence.send(:sync_up, caller[0], *ids)
          end
        end

        private

        def current_sequence=(seq)
          @current_sequence = seq
        end

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
