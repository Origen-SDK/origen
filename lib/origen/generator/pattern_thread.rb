module Origen
  class Generator
    # An instance of PatternThread is created for each parallel thread of execution
    # in a pattern sequence. One instance of this class is also created to represent
    # the original main thread in addition to those created by calling seq.in_parallel
    class PatternThread
      # Returns the parent pattern sequence object
      attr_reader :sequence
      attr_reader :pending_cycles

      def initialize(sequence, block, primary = false)
        @sequence = sequence
        @block = block
        @primary = primary
        @event = Concurrent::Event.new
        @pending_cycles = nil
      end

      # Returns true if this is main thread (the one from which all in_parallel threads
      # have been branched from)
      # def primary?
      #  @primary
      # end

      def execute
        @thread = Thread.new do
          PatSeq.send(:thread=, self)
          @block.call(sequence)
          sequence.send(:thread_completed, self)
        end
      end

      def waiting_for_serialize
        sequence.send(:thread_ready_to_cycle)
        wait
      end

      def cycle(options)
        @pending_cycles = options[:repeat] || 1
        sequence.send(:thread_ready_to_cycle)
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

      # Will block until told to resume by the pattern sequence
      def wait
        @event.reset
        @event.wait
      end

      def resume(completed_cycles = nil)
        @pending_cycles -= completed_cycles if @pending_cycles
        @event.set
      end
    end
  end
end
