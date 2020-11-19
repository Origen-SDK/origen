module Origen
  class Generator
    # An instance of PatternThread is created for each parallel thread of execution
    # in a pattern sequence. One instance of this class is also created to represent
    # the original main thread in addition to those created by calling seq.in_parallel
    class PatternThread
      # Returns the parent pattern sequence object
      attr_reader :sequence
      attr_reader :pending_cycles
      attr_reader :id
      attr_reader :reservations
      attr_reader :cycle_count_start
      attr_reader :cycle_count_stop
      # A record of when the thread is active to construct the execution profile
      attr_reader :events

      def initialize(id, sequence, block, primary = false, pre_block = nil)
        if primary
          @cycle_count_start = 0
        else
          @cycle_count_start = current_cycle_count
        end
        @events = [[:active, cycle_count_start]]
        @id = id.to_sym
        @sequence = sequence
        @block = block
        @pre_block = pre_block
        @primary = primary
        @running = Concurrent::Event.new
        @waiting = Concurrent::Event.new
        @pending_cycles = nil
        @completed = false
        @reservations = {}
      end

      # Returns true if this is main thread (the one from which all in_parallel threads
      # have been branched from)
      def primary?
        @primary
      end

      # @api private
      #
      # This method is called once by the pattern sequence to start a new thread. It will block until
      # the thread is in the waiting state.
      def start
        @thread = Thread.new do
          PatSeq.send(:thread=, self)
          wait
          @pre_block.call if @pre_block
          @block.call(sequence)
          sequence.send(:thread_completed, self)
          record_cycle_count_stop
          @completed = true
          wait
        end
        @waiting.wait
      end

      def record_cycle_count_stop
        @cycle_count_stop = current_cycle_count
        events << [:stopped, cycle_count_stop]
        events.freeze
      end

      def record_active
        events << [:active, current_cycle_count]
      end

      def current_cycle_count
        tester.try(:cycle_count) || 0
      end

      def execution_profile(start, stop, step)
        events = @events.dup
        cycles = start
        state = :inactive
        line = ''
        ((stop - start) / step).times do |i|
          active_cycles = 0
          while events.first && events.first[1] >= cycles && events.first[1] < cycles + step
            event = events.shift
            # Bring the current cycles up to this event point applying the current state
            if state == :active
              active_cycles += event[1] - cycles
            end
            state = event[0] == :active ? :active : :inactive
            cycles = event[1]
          end

          # Bring the current cycles up to the end of this profile tick
          if state == :active
            active_cycles += ((i + 1) * step) - cycles
          end
          cycles = ((i + 1) * step)

          if active_cycles == 0
            line += '_'
          elsif active_cycles > (step * 0.5)
            line += '█'
          else
            line += '▄'
          end
        end
        line
      end

      # Will be called when the thread can't execute its next cycle because it is waiting to obtain a
      # lock on a serialized block
      def waiting_for_serialize(serialize_id, skip_event = false)
        # puts "Thread #{id} is blocked waiting for #{serialize_id}"
        events << [:waiting, current_cycle_count] unless skip_event
        wait
      end

      # Will be called when the thread can't execute its next cycle because it is waiting for another
      # thread to complete
      def waiting_for_thread(skip_event = false)
        events << [:waiting, current_cycle_count] unless skip_event
        wait
      end

      # Will be called when the thread is ready for the next cycle
      def cycle(options)
        @pending_cycles = options[:repeat] || 1
        # If there are threads pending start and we are about to enter a long delay, block for only
        # one cycle to give them a change to get underway and make use of this delay
        if @pending_cycles > 1 && sequence.send(:threads_waiting_to_start?)
          remainder = @pending_cycles - 1
          @pending_cycles = 1
        end
        wait
        @pending_cycles = remainder if remainder
        # If the sequence did not do enough cycles in that round to satisfy this thread, then go back
        # around to complete the remainder before continuing with the rest of the pattern
        if @pending_cycles == 0
          @pending_cycles = nil
        elsif @pending_cycles > 0
          @pending_cycles.cycles
        else
          fail "Something has gone wrong @pending_cycles is #{@pending_cycles}"
        end
      end

      # @api private
      def executed_cycles(cycles)
        @pending_cycles -= cycles if @pending_cycles
      end

      def completed?
        @completed
      end

      # Returns true if the thread is currently waiting for the pattern sequence to advance it
      def waiting?
        @waiting.set?
      end

      # This should be called only by the pattern thread itself, and will block it until it is told to
      # advance by the pattern sequence running in the main thread
      def wait
        @running.reset
        @waiting.set
        @running.wait
      end

      # This should be called only by the pattern sequence running in the main thread, it will un-block the
      # pattern thread which is currently waiting, and it will block the main thread until the pattern thread
      # reaches the next wait point (or completes)
      def advance(completed_cycles = nil)
        @waiting.reset
        @running.set         # Release the pattern thread
        @waiting.wait        # And wait for it to reach the next wait point
      end
    end
  end
end
