require 'io/console'

module Origen
  class Generator
    # Manages a single pattern sequence, i.e. an instance of PatternSequence is
    # created for every Pattern.sequence do ... end block
    class PatternSequence
      def initialize(name, block)
        @number_of_threads = 1
        @name = name
        @running_thread_ids = { main: true }
        # The contents of the main Pattern.sequence block will be executed as a thread and treated
        # like any other parallel block
        thread = PatternThread.new(:main, self, block, true)
        threads << thread
        active_threads << thread
        PatSeq.send(:current_sequence=, self)
        @sync_ups = {}
      end

      # Execute the given pattern
      def run(pattern_name)
        name = Pathname.new(pattern_name.to_s).basename
        ss "START OF PATTERN: #{name}"
        # Give the app a chance to handle pattern dispatch
        skip = false
        Origen.app.listeners_for(:before_pattern_lookup).each do |listener|
          skip ||= !listener.before_pattern_lookup(pattern_name.to_s)
        end
        unless skip
          pattern = Origen.generator.pattern_finder.find(pattern_name.to_s, {})
          pattern = pattern[:pattern] if pattern.is_a?(Hash)
          load pattern
        end
        ss "END OF PATTERN: #{name}"
      end
      alias_method :call, :run

      # Execute the given block in a new concurrent thread
      def thread(id = nil, &block)
        @number_of_threads += 1
        id ||= "thread#{@number_of_threads}".to_sym
        # Just stage the request for now, it will be started at the end of the current execute loop
        @parallel_blocks_waiting_to_start ||= []
        @parallel_blocks_waiting_to_start << [id, block]
        @running_thread_ids[id] = true
      end
      alias_method :in_parallel, :thread

      def wait_for_threads_to_complete(*ids)
        completed = false
        blocked = false
        ids = ids.map(&:to_sym)
        all = ids.empty? || ids.include?(:all)
        until completed
          if all
            limit = current_thread.id == :main ? 1 : 2
            if @running_thread_ids.size > limit
              current_thread.waiting_for_thread(blocked)
              blocked = true
            else
              current_thread.record_active if blocked
              completed = true
            end
          else
            if ids.any? { |id| @running_thread_ids[id] }
              current_thread.waiting_for_thread(blocked)
              blocked = true
            else
              current_thread.record_active if blocked
              completed = true
            end
          end
        end
      end
      alias_method :wait_for_thread, :wait_for_threads_to_complete
      alias_method :wait_for_threads, :wait_for_threads_to_complete
      alias_method :wait_for_thread_to_complete, :wait_for_threads_to_complete

      private

      def sync_up(location, *ids)
        options = ids.pop if ids.last.is_a?(Hash)
        options ||= {}
        ids = ids.map(&:to_sym)
        if ids.empty? || ids.include?(:all)
          ids = @running_thread_ids.keys
          ids.delete(:main) unless options[:include_main]
        end
        # Just continue if this thread is not in the list
        return unless ids.include?(current_thread.id)
        # Don't need to worry about race conditions here as Origen only allows 1 thread
        # to be active at a time
        if @sync_ups[location]
          @sync_ups[location][:arrived] << current_thread.id
        else
          @sync_ups[location] = { required: Set.new, arrived: Set.new, completed: false }
          ids.each { |id| @sync_ups[location][:required] << id }
          @sync_ups[location][:arrived] << current_thread.id
        end
        if @sync_ups[location][:required] == @sync_ups[location][:arrived]
          @sync_ups[location][:completed] = true
        end
        blocked = false
        until @sync_ups[location][:completed]
          current_thread.waiting_for_thread(blocked)
          blocked = true
          Origen.log.debug "Waiting for sync_up: #{@sync_ups}"
        end
        current_thread.record_active if blocked
      end

      def thread_running?(id)
        @running_thread_ids[id]
      end

      def current_thread
        PatSeq.thread
      end

      def log_execution_profile
        if threads.size > 1
          thread_id_size = threads.map { |t| t.id.to_s.size }.max
          line_size = IO.console.winsize[1] - 35 - thread_id_size
          line_size -= 16 if tester.try(:sim?)
          cycles_per_tick = (@cycle_count_stop / (line_size * 1.0)).ceil
          if tester.try(:sim?)
            execution_time = tester.execution_time_in_ns / 1_000_000_000.0
          else
            execution_time = Origen.app.stats.execution_time_for(Origen.app.current_job.output_pattern)
          end
          Origen.log.info ''
          tick_time = execution_time / line_size

          Origen.log.info "Concurrent execution profile (#{pretty_time(tick_time)}/increment):"
          Origen.log.info

          number_of_ticks = @cycle_count_stop / cycles_per_tick

          ticks_per_step = 0
          step_size = 0.1.us

          while ticks_per_step < 10
            step_size = step_size * 10
            ticks_per_step = step_size / tick_time
          end

          ticks_per_step = ticks_per_step.ceil
          step_size = tick_time * ticks_per_step

          if tester.try(:sim?)
            padding = '.' + (' ' * (thread_id_size + 1))
          else
            padding = ' ' * (thread_id_size + 2)
          end
          scale_step = '|' + ('-' * (ticks_per_step - 1))
          number_of_steps = (number_of_ticks / ticks_per_step) + 1
          scale = scale_step * number_of_steps
          scale = scale[0, number_of_ticks]
          Origen.log.info padding + scale

          scale = ''
          number_of_steps.times do |i|
            scale += pretty_time(i * step_size, 1).ljust(ticks_per_step)
          end
          scale = scale[0, number_of_ticks]
          Origen.log.info padding + scale

          threads.each do |thread|
            line = thread.execution_profile(0, @cycle_count_stop, cycles_per_tick)
            Origen.log.info ''
            Origen.log.info "#{thread.id}: ".ljust(thread_id_size + 2) + line
          end
          Origen.log.info ''
        end
      end

      def pretty_time(time, number_decimal_places = 0)
        return '0' if time == 0
        if time < 1.us
          "%.#{number_decimal_places}fns" % (time * 1_000_000_000)
        elsif time < 1.ms
          "%.#{number_decimal_places}fus" % (time * 1_000_000)
        elsif time < 1.s
          "%.#{number_decimal_places}fms" % (time * 1_000)
        else
          "%.#{number_decimal_places}fs" % tick_time
        end
      end

      def thread_completed(thread)
        @running_thread_ids.delete(thread.id)
        active_threads.delete(thread)
      end

      def threads
        @threads ||= []
      end

      def active_threads
        @active_threads ||= []
      end

      def threads_waiting_to_start?
        @parallel_blocks_waiting_to_start
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
              threads << thread
              active_threads << thread
              thread.start
            end
            @parallel_blocks_waiting_to_start = nil
          end
        end
        @cycle_count_stop = threads.first.current_cycle_count
      end
    end
  end
end
