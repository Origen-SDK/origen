module Origen
  class Generator
    # Manages a single pattern sequence, i.e. an instance of PatternSequence is
    # created for every Pattern.sequence do ... end block
    class PatternSequence
      attr_reader :number_of_threads
      attr_reader :number_of_completed_threads
      attr_reader :latch

      def initialize(name, block)
        @name = name
        threads << PatternThread.new(self, block, true)
        @number_of_completed_threads = 0
        @number_of_threads = 1
        @latch = Concurrent::CountDownLatch.new(1)
      end
      
      # Execute the given pattern
      def run(pattern_name)
        pattern = Origen.generator.pattern_finder.find(pattern_name.to_s, {})
        pattern = pattern[:pattern] if pattern.is_a?(Hash)
        load pattern
      end
      alias :call :run

      def in_parallel(&block)
        @number_of_threads += 1
        thread = PatternThread.new(self, block) 
        threads << thread
        thread.execute
      end

      private

      def thread_completed
        @number_of_completed_threads += 1
        latch.count_down
      end

      def threads
        @threads ||= []
      end

      def execute
        threads.first.execute
        until @number_of_threads == @number_of_completed_threads
          #puts "Waiting for cycle"
          latch.wait
          #puts "Cycle received"
          @latch = Concurrent::CountDownLatch.new(@number_of_threads - @number_of_completed_threads)
          cycs = threads.map { |t| t.pending_cycles || 1 }.min
          cycs.cycles
          threads.each { |t| t.resume!(cycs) }
        end
      end
    end
  end
end
