module Origen
  class Generator
    # Manages a single pattern sequence, i.e. an instance of PatternSequence is
    # created for every Pattern.sequence do ... end block
    class PatternSequence
      def initialize(name, block)
        @name = name
        # The contents of the main Pattern.sequence block will be executed as a thread and treated
        # like any other parallel block
        thread = PatternThread.new(self, block, true)
        threads << thread
        active_threads << thread
        @number_of_completed_threads = 0
        @number_of_threads = 1
      end

      # Execute the given pattern
      def run(pattern_name)
        pattern = Origen.generator.pattern_finder.find(pattern_name.to_s, {})
        pattern = pattern[:pattern] if pattern.is_a?(Hash)
        load pattern
      end
      alias_method :call, :run

      def in_parallel(&block)
        # To ensure deterministic behavior the block won't be started until the next cycle rather
        # than letting it get underway asynchronously
        PatSeq.with_sole_access do
          @parallel_blocks_waiting_to_start ||= []
          @parallel_blocks_waiting_to_start << block
        end
      end

      private

      # Called by a thread when it is ready to cycle
      def thread_ready_to_cycle
        @latch.count_down
      end

      def thread_completed(thread)
        @number_of_completed_threads += 1
        active_threads.delete(thread)
        @latch.count_down
      end

      def threads
        @threads ||= []
      end

      def active_threads
        @active_threads ||= []
      end

      def execute
        active_threads.first.execute
        @latch = Concurrent::CountDownLatch.new(1)
        until @number_of_threads == @number_of_completed_threads
          @latch.wait
          cycs = active_threads.map { |t| t.pending_cycles || 1 }.min
          cycs.cycles if cycs
          if @parallel_blocks_waiting_to_start
            new_threads = @parallel_blocks_waiting_to_start.map do |block|
              @number_of_threads += 1
              thread = PatternThread.new(self, block)
              threads << thread
              thread
            end
            @parallel_blocks_waiting_to_start = nil
          end
          @latch = Concurrent::CountDownLatch.new(@number_of_threads - @number_of_completed_threads)
          active_threads.each { |t| t.resume(cycs) }
          if new_threads
            new_threads.each do |t|
              active_threads << t
              t.execute
            end
            new_threads = nil
          end
        end
      end
    end
  end
end
