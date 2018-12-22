module Origen
  class Generator
    # An instance of PatternThread is created for each parallel thread of execution
    # in a pattern sequence. One instance of this class is also created to represent
    # the original main thread in addition to those created by calling seq.in_parallel
    class PatternThread

      # Returns the parent pattern sequence object 
      attr_reader :sequence
      attr_reader :resume
      attr_reader :pending_cycles

      def initialize(sequence, block, primary=false)
        @sequence = sequence
        @block = block
        @primary = primary
        @resume = Concurrent::Event.new
        @pending_cycles = 0
      end

      # Returns true if this is main thread (the one from which all in_parallel threads
      # have been branched from)
      def primary?
        @primary
      end

      def execute
        @thread = Thread.new do
          PatSeq.send(:thread=, self)
          @block.call(sequence)
          sequence.send(:thread_completed)
        end
      end

      def cycle(options)
        resume.reset
        @pending_cycles = options[:repeat] || 1
        sequence.latch.count_down 
        resume.wait
        @pending_cycles.cycles if @pending_cycles != 0
      end

      def resume!(completed_cycles)
        @pending_cycles -= completed_cycles
        resume.set
      end
    end
  end
end
