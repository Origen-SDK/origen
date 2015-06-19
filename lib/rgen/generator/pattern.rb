module RGen
  class Generator
    class Pattern
      include Comparator

      class DummyIterator
        def invoke(*_args)
          yield
        end

        def enabled?(_options)
          false
        end
      end

      def log
        RGen.log
      end

      # Returns the options passed to the current create block
      def create_options
        @create_options || {}
      end

      # The recommended way to create a pattern is to wrap it within a Pattern.create
      # block, however occasionally the need may arise to manually open and close
      # a pattern, this method can be used in that case in association with the close
      # method.
      #
      # Pattern iterators are not supported when creating a pattern in this way.
      def open(options = {})
        if block_given?
          create(options) do |*args|
            yield(*args)
          end
        else
          job.output_file_body = options.delete(:name).to_s if options[:name]

          # Refresh the target to start all settings from scratch each time
          # This is an easy way to reset all registered values
          RGen.app.reload_target!(skip_first_time: true)

          # Final call back to the project to allow it to make any pattern name specific
          # configuration changes
          RGen.app.listeners_for(:before_pattern).each do |listener|
            listener.before_pattern(job.output_pattern_filename)
          end

          # Allow custom pattern postfix
          unless options[:pat_postfix].to_s.empty?
            job.output_pattern_filename = job.output_pattern_filename.sub(job.output_postfix + job.output_extension, "_#{options[:pat_postfix]}" + job.output_postfix + job.output_extension)
          end

          pattern_open(options)
        end
      end

      def close(options = {})
        pattern_close(options)
      end

      def create(options = {})
        @create_options = options
        unless RGen.tester
          puts 'The current target has not instantiated a tester and pattern generation cannot run.'
          puts 'Add something like this to your target file:'
          puts ''
          puts '  $tester = RGen::Tester::J750.new'
          puts ''
          exit 1
        end
        RGen.tester.generating = :pattern

        job.output_file_body = options.delete(:name).to_s if options[:name]

        # Order the iterators by the order that their enable keys appear in the options, pad
        # any missing iterators with a dummy function...
        iterators = options.map do |key, _val|
          RGen.app.pattern_iterators.find { |iterator| iterator.key == key }
        end.compact
        iterators << DummyIterator.new while iterators.size < 10

        args = []

        # Couldn't get this to work fully dynamically, so hard-coded for 10 custom
        # iterators for now, should be plenty for any application in the meantime.
        # Should revisit this when time allows and remove this limitation by changing
        # this to a recursive structure.
        iterators[0].invoke(options) do |arg0|
          args[0] = arg0
          iterators[1].invoke(options) do |arg1|
            args[1] = arg1
            iterators[2].invoke(options) do |arg2|
              args[2] = arg2
              iterators[3].invoke(options) do |arg3|
                args[3] = arg3
                iterators[4].invoke(options) do |arg4|
                  args[4] = arg4
                  iterators[5].invoke(options) do |arg5|
                    args[5] = arg5
                    iterators[6].invoke(options) do |arg6|
                      args[6] = arg6
                      iterators[7].invoke(options) do |arg7|
                        args[7] = arg7
                        iterators[8].invoke(options) do |arg8|
                          args[8] = arg8
                          iterators[9].invoke(options) do |arg9|
                            args[9] = arg9
                            # Refresh the target to start all settings from scratch each time
                            # This is an easy way to reset all registered values
                            RGen.app.reload_target!(skip_first_time: true)

                            # Final call back to the project to allow it to make any pattern name specific
                            # configuration changes
                            RGen.app.listeners_for(:before_pattern).each do |listener|
                              listener.before_pattern(job.output_pattern_filename)
                            end

                            # Work out the final pattern name based on the current iteration
                            job.reset_output_pattern_filename
                            iterators.each_with_index do |iterator, i|
                              if iterator.enabled?(options)
                                job.output_pattern_filename =
                                  iterator.pattern_name.call(job.output_pattern_filename, args[i])
                              end
                            end

                            # Allow custom pattern postfix
                            unless options[:pat_postfix].to_s.empty?
                              job.output_pattern_filename = job.output_pattern_filename.sub(job.output_postfix + job.output_extension, "_#{options[:pat_postfix]}" + job.output_postfix + job.output_extension)
                            end

                            pattern_wrapper(iterators, args, options) do
                              # Call iterator setups, whatever these return are passed to the pattern
                              yield_items = []
                              iterators.each_with_index do |iterator, i|
                                if iterator.enabled?(options)
                                  yield_items << iterator.setup.call(args[i])
                                end
                              end

                              yield(*yield_items)
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
        @create_options = nil
      end # create

      # Split a running Pattern.create block into multiple patterns.
      #
      # The output that has been generated up until the point where
      # this is called will be written and a new pattern will be
      # opened to contain the remainder of the pattern content
      # generated by the block.
      #
      # Each additional pattern section created by calling this method
      # will have '_partN' appended to the original pattern name.
      def split(options = {})
        @split_counter ||= 0
        @split_counter += 1
        name = job.output_file_body
        pattern_close(options.merge(call_shutdown_callbacks: false))
        if name =~ /part\d+/
          name.gsub!(/part\d+/, "part#{@split_counter}")
        else
          name = "#{name}_part#{@split_counter}"
        end
        job.output_file_body = name
        pattern_open(options.merge(call_startup_callbacks: false))
      end

      # This is called before each new pattern source is executed
      #
      # @api private
      def reset
        $desc = nil  # Clear the description
      end

      private

      def job
        # The only time the job is not present should be in a test situation, e.g.
        # when calling Pattern.create within a spec test
        RGen.app.current_job || RGen::Generator::Job.new('anonymous', testing: true)
      end

      def stage
        RGen.generator.stage
      end

      def stats
        RGen.app.stats
      end

      # Creates a header and footer for the pattern based on the current tester and any supplied options
      def pattern_wrapper(iterators, args, options = {})
        options[:iterators] = iterators
        options[:args] = args
        pattern_open(options)
        yield      # Pass control back to the pattern source
        pattern_close(options)
      end

      def header
        RGen.tester.pre_header if RGen.tester.doc?
        c2 '*' * 75
        if $desc
          c2 'DESCRIPTION:'
          $desc.split(/\n/).each { |line| cc line }
          c2 '*' * 75
        end
        c2 'GENERATED:'
        c2 "  Time:    #{RGen.launch_time}"
        c2 "  By:      #{RGen.current_user.name}"
        c2 "  Command: rgen g #{job.requested_pattern} -t #{RGen.target.file.basename}"
        c2 '*' * 75
        c2 'ENVIRONMENT:'
        c2 '  Application'
        c2 "    Vault:     #{RGen.config.vault}"
        c2 "    Version:   #{RGen.app.version}"
        c2 "    Workspace: #{RGen.root}"
        c2 '  RGen'
        c2 "    Vault:     #{RGen.vault}"
        c2 "    Version:   #{RGen.version}"
        c2 "    Workspace: #{RGen.top}"
        c2 '*' * 75
        if RGen.config.pattern_header
          c2 '*' * 75
        end
        RGen.tester.close_text_block if RGen.tester.doc?
      end

      def pattern_open(options = {})
        options = {
          call_startup_callbacks: true
        }.merge(options)

        iterators = options.delete(:iterators) || []

        args = options.delete(:args)

        if RGen.tester.generate?
          # Now the pattern name is established delete any existing versions of this pattern
          # to make it clearer that something has gone wrong if there is an error generating the new one
          unless job.test?
            File.delete(job.output_pattern) if File.exist?(job.output_pattern)

            if options[:inhibit]
              log.info "Generating...  #{job.output_pattern_directory}/#{job.output_pattern_filename}".ljust(50)
            else
              log.info "Generating...  #{job.output_pattern_directory}/#{job.output_pattern_filename}".ljust(50)
            end
          end
        end

        RGen.tester.inhibit_comments = job.no_comments? if RGen.tester.respond_to?(:inhibit_comments=)

        stage.reset!

        stage.bank = options[:inhibit] ? :null : :body

        if options.delete(:call_startup_callbacks)

          skip_startup = false

          # Call the iterator startup methods, if any of them return false/nil the standard
          # startup callbacks will be skipped
          iterators.each_with_index do |iterator, i|
            if iterator.enabled?(options)
              skip_startup = !iterator.startup.call(options, args[i]) || skip_startup
            end
          end

          unless skip_startup || options[:skip_startup]
            # Call startup callbacks
            RGen.app.listeners_for(:startup).each do |listener|
              listener.startup(options)
            end
          end

        end
      end

      def pattern_close(options = {})
        options = {
          call_shutdown_callbacks: true
        }.merge(options)

        bank = options[:inhibit] ? :null : :body
        stage.with_bank bank do
          if options.delete(:call_shutdown_callbacks) && !options[:skip_shutdown]
            # Call shutdown callbacks
            RGen.app.listeners_for(:shutdown, top_level: :last).each do |listener|
              listener.shutdown(options)
            end
          end

          # Now the pattern has run call the render method if the tester uses a template
          RGen.tester.render_template
          RGen.tester.render_body
        end

        bank = options[:inhibit] ? :null : :footer
        stage.with_bank bank do
          RGen.tester.pattern_footer(options)
          RGen.tester.render_footer
        end

        # Generate the pattern header, do this at the very end so that it can
        # dynamically pick up what import subs are required and things like that
        if RGen.tester.generate?
          bank = options[:inhibit] ? :null : :header
          stage.with_bank bank do
            header
            options[:pattern] = job.output_pattern_filename.sub(job.output_extension, '') # remove output extension
            RGen.tester.pattern_header(options)
            RGen.tester.render_header
          end
        end

        unless options[:inhibit] || !RGen.tester.generate? || job.test?
          stats.collect_for_pattern(job.output_pattern) do
            File.open(job.output_pattern, 'w') do |f|
              [:header, :body, :footer].each do |section|
                RGen.tester.format(stage.bank(section), section) do |line|
                  f.puts line
                end
              end
            end
          end

          log.info ' '
          log.info "Pattern vectors: #{stats.number_of_vectors_for(job.output_pattern).to_s.ljust(10)}"
          log.info 'Execution time'.ljust(15) + ': %.6f' % stats.execution_time_for(job.output_pattern)
          log.info '----------------------------------------------------------------------'
          check_for_changes(job.output_pattern, job.reference_pattern)
          stats.record_pattern_completion(job.output_pattern)
        end

        if RGen.tester.generate?
          RGen.app.listeners_for(:pattern_generated).each do |listener|
            listener.pattern_generated(Pathname.new(job.output_pattern))
          end
        end
      end
    end
  end
end
