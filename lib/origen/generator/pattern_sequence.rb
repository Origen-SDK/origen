module Origen
  class Generator
    # Manages a single pattern sequence, i.e. an instance of PatternSequence is
    # created for every Pattern.sequence do ... end block
    class PatternSequence
      def initialize(name, block)
        @number_of_threads = 1
        @name = name
        # The contents of the main Pattern.sequence block will be executed as a thread and treated
        # like any other parallel block
        thread = PatternThread.new(:main, self, block, true)
        threads << thread
        active_threads << thread
      end

      # Execute the given pattern
      def run(pattern_name)
        pattern = Origen.generator.pattern_finder.find(pattern_name.to_s, {})
        pattern = pattern[:pattern] if pattern.is_a?(Hash)
        load pattern
      end
      alias_method :call, :run

      def in_parallel(id = nil, &block)
        @number_of_threads += 1
        id ||= "thread#{@number_of_threads}".to_sym
        # Just stage the request for now, it will be started at the end of the current execute loop
        @parallel_blocks_waiting_to_start ||= []
        @parallel_blocks_waiting_to_start << [id, block]
      end

      private

      def thread_completed(thread)
        active_threads.delete(thread)
      end

      def threads
        @threads ||= []
      end

      def active_threads
        @active_threads ||= []
      end

      def execute
        active_threads.first.start
        until active_threads.empty?
          # Advance all threads to their next cycle point in sequential order. Keeping tight control of
          # when threads are running in this way ensures that the output is deterministic no matter what
          # computer it is running on, and ensures that the application code does not have to worry about
          # race conditions.
          cycs = active_threads.map do |t|
            t.advance
            t.pending_cycles
          end.compact.min

          if cycs
            # Now generate the required number of cycles which is defined by the thread that has the least
            # amount of cycles ready to go.
            # Since tester.cycle is being called by the master process here it will generate as normal (as
            # opposed to when called from a thread in which case it causes the thread to wait).
            cycs.cycles

            # Now let each thread know how many cycles we just generated, so they can decide whether they
            # need to wait for more cycles or if they can start preparing the next one
            active_threads.each { |t| t.executed_cycles(cycs) }
          end

          if @parallel_blocks_waiting_to_start
            @parallel_blocks_waiting_to_start.each do |id, block|
              thread = PatternThread.new(id, self, block)
              active_threads << thread
              thread.start
            end
            @parallel_blocks_waiting_to_start = nil
          end
        end
      end
    end
  end
end
