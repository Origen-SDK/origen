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

      def initialize(id, sequence, block, primary = false)
        @id = id
        @sequence = sequence
        @block = block
        @primary = primary
        @running = Concurrent::Event.new
        @waiting = Concurrent::Event.new
        @pending_cycles = nil
        @completed = false
      end

      # Returns true if this is main thread (the one from which all in_parallel threads
      # have been branched from)
      # def primary?
      #  @primary
      # end

      # @api private
      #
      # This method is called once by the pattern sequence to start a new thread. It will block until
      # the thread is in the waiting state.
      def start
        @thread = Thread.new do
          PatSeq.send(:thread=, self)
          wait
          @block.call(sequence)
          sequence.send(:thread_completed, self)
          @completed = true
          wait
        end
        @waiting.wait
      end

      # Will be called when the thread can't execute its next cycle because it is waiting to obtain a
      # lock on a serialized block
      def waiting_for_serialize(serialize_id)
        # puts "Thread #{id} is blocked waiting for #{serialize_id}"
        wait
      end

      # Will be called when the thread is ready for the next cycle
      def cycle(options)
        @pending_cycles = options[:repeat] || 1
        wait
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
