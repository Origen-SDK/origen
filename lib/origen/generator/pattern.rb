module Origen
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
        Origen.log
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
          Origen.app.reload_target!(skip_first_time: true)

          # Final call back to the project to allow it to make any pattern name specific
          # configuration changes
          Origen.app.listeners_for(:before_pattern).each do |listener|
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

      def sequence(options = {}, &block)
        @create_options = options
        unless Origen.tester
          puts 'The current target has not instantiated a tester and pattern generation cannot run.'
          puts 'Add something like this to an environment file:'
          puts
          puts '  Origen::Tester::J750.new'
          puts
          puts
          puts 'Then select it by running:  origen e <environment name>'
          exit 1
        end
        Origen.tester.generating = :pattern

        job.output_file_body = options.delete(:name).to_s if options[:name]

        # Refresh the target to start all settings from scratch each time
        # This is an easy way to reset all registered values
        Origen.app.reload_target!(skip_first_time: true)

        # Final call back to the project to allow it to make any pattern name specific
        # configuration changes
        Origen.app.listeners_for(:before_pattern).each do |listener|
          listener.before_pattern(job.output_pattern_filename)
        end

        ## Allow custom pattern postfix
        # unless options[:pat_postfix].to_s.empty?
        #  job.output_pattern_filename = job.output_pattern_filename.sub(job.output_postfix + job.output_extension, "_#{options[:pat_postfix]}" + job.output_postfix + job.output_extension)
        # end

        @pattern_sequence = true

        # The startup callbacks need to be skipped for now until the main thread is open for business
        pattern_wrapper([], [], options.merge(call_startup_callbacks: false)) do
          # The startup callbacks, if required, need to be wrapped up in a closure for calling
          # later by the main thread
          if (options.key?(:call_startup_callbacks) && !options[:call_startup_callbacks]) || options[:skip_startup]
            pre_block = nil
          else
            pre_block = proc do
              # Call startup callbacks
              Origen.app.listeners_for(:startup).each do |listener|
                listener.startup(options)
              end
            end
          end
          PatternSequencer.send(:active=, true)
          @pattern_sequence = PatternSequence.new(job.output_pattern_filename, block, pre_block)
          @pattern_sequence.send(:execute)
          PatternSequencer.send(:active=, false)
        end
        @pattern_sequence = false
        @create_options = nil
      end

      def create(options = {})
        if @pattern_sequence
          yield
        else
          @create_options = options
          unless Origen.tester
            puts 'The current target has not instantiated a tester and pattern generation cannot run.'
            puts 'Add something like this to an environment file:'
            puts
            puts '  Origen::Tester::J750.new'
            puts
            puts
            puts 'Then select it by running:  origen e <environment name>'
            exit 1
          end
          Origen.tester.generating = :pattern

          job.output_file_body = options.delete(:name).to_s if options[:name]

          # Order the iterators by the order that their enable keys appear in the options, pad
          # any missing iterators with a dummy function...
          iterators = options.map do |key, _val|
            Origen.app.pattern_iterators.find { |iterator| iterator.key == key }
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
                              Origen.app.reload_target!(skip_first_time: true)

                              # Final call back to the project to allow it to make any pattern name specific
                              # configuration changes
                              Origen.app.listeners_for(:before_pattern).each do |listener|
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

                              # Allow custom pattern prefix
                              unless options[:pat_prefix].to_s.empty?
                                if job.output_prefix.empty?
                                  job.output_pattern_filename = "#{options[:pat_prefix]}_" + job.output_pattern_filename
                                else
                                  job.output_pattern_filename = job.output_pattern_filename.sub(job.output_prefix, job.output_prefix + "#{options[:pat_prefix]}_")
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
        split_name = options.delete(:name) || ''
        pattern_close(options.merge(call_shutdown_callbacks: false))
        job.inc_split_counter(split_name)
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
        Origen.app.current_job || Origen::Generator::Job.new('anonymous', testing: true)
      end

      def stage
        Origen.generator.stage
      end

      def stats
        Origen.app.stats
      end

      # Creates a header and footer for the pattern based on the current tester and any supplied options
      def pattern_wrapper(iterators, args, options = {})
        pattern_open(options.merge(iterators: iterators, args: args))
        yield      # Pass control back to the pattern source
        pattern_close(options)
      end

      def header
        Origen.tester.pre_header if Origen.tester.doc?
        inject_separator
        if $desc
          c2 'DESCRIPTION:'
          $desc.split(/\n/).each { |line| cc line }
          inject_separator
        end
        c2 'GENERATED:'
        c2 "  Time:    #{Origen.launch_time}"
        c2 "  By:      #{Origen.current_user.name}"
        c2 "  Mode:    #{Origen.mode}"
        l = "  Command: origen g #{job.requested_pattern} -t #{Origen.target.file.basename}"
        if Origen.environment && Origen.environment.file
          l += " -e #{Origen.environment.file.basename}"
        end
        c2(l)
        inject_separator
        c2 'ENVIRONMENT:'
        c2 '  Application'
        if Origen.app.rc
          if Origen.app.rc.git?
            c2 "    Source:    #{Origen.config.rc_url}"
          else
            c2 "    Vault:     #{Origen.config.vault}"
          end
        end
        c2 "    Version:   #{Origen.app.version}"
        unless Origen.app.config.release_externally
          c2 "    Workspace: #{Origen.root}"
        end
        if Origen.app.rc && Origen.app.rc.git?
          begin
            @branch ||= Origen.app.rc.current_branch
            @commit ||= Origen.app.rc.current_commit
            status = "#{@branch}(#{@commit})"
            @pattern_local_mods = !Origen.app.rc.local_modifications.empty? unless @pattern_local_mods_fetched
            @pattern_local_mods_fetched = true
            status += ' (+local edits)' if @pattern_local_mods
            c2 "    Branch:    #{status}"
          rescue
            # No problem, we did our best
          end
        end
        c2 '  Origen'
        c2 '    Source:    https://github.com/Origen-SDK/origen'
        c2 "    Version:   #{Origen.version}"
        unless Origen.app.plugins.empty?
          c2 '  Plugins'
          Origen.app.plugins.sort_by { |p| p.name.to_s }.each do |plugin|
            c2 "    #{plugin.name}:".ljust(30) + plugin.version
          end
        end
        inject_separator

        unless Origen.app.plugins.empty?
          # Plugins can use config.shared_pattern_header to inject plugin-specific comments into the patterns header
          header_printed = false
          Origen.app.plugins.sort_by { |p| p.name.to_s }.each do |plugin|
            unless plugin.config.shared_pattern_header.nil?
              unless header_printed
                c2 'Header Comments From Shared Plugins:'
                header_printed = true
              end
              inject_pattern_header(
                config_loc:      plugin,
                scope:           :shared_pattern_header,
                message:         "Header Comments From Shared Plugin: #{plugin.name}:",
                message_spacing: 2,
                line_spacing:    4,
                no_separator:    true
              )
            end
          end
          inject_separator if header_printed
        end

        if Origen.app.plugins.current && !Origen.app.plugins.current.config.send(:current_plugin_pattern_header).nil?
          # The top level plugin (if one is set) can further inject plugin-specific comment into the header.
          # These will only appear if the plugin is the top-level plugin though.
          inject_pattern_header(
            config_loc: Origen.app.plugins.current,
            scope:      :current_plugin_pattern_header,
            message:    "Header Comments From The Current Plugin: #{Origen.app.plugins.current.name}:"
          )
        end

        unless Origen.app.config.send(:application_pattern_header).nil?
          inject_pattern_header(
            config_loc: Origen.app,
            scope:      :application_pattern_header,
            message:    "Header Comments From Application: #{Origen.app.name}:"
          )
        end

        if Origen.config.pattern_header
          Origen.log.deprecated 'Origen.config.pattern_header is deprecated.'
          Origen.log.deprecated 'Please use config.shared_pattern_header, config.application_pattern_header, or config.current_plugin_pattern_header instead.'
          inject_separator
        end
        Origen.tester.close_text_block if Origen.tester.doc?
      end

      def inject_separator(options = {})
        separator_length = options[:size] || 75
        c2('*' * separator_length)
      end

      def inject_pattern_header(config_loc:, scope:, message:, **options)
        message_spacing = options[:message_spacing] || 0
        line_spacing = options[:line_spacing] || 2
        no_separator = options[:no_separator] || false

        # Print a warning if any of the pattern header configs have an arity greater than 1.
        # Anything over 1 won't be used and may cause confusion.
        if config_loc.config.send(scope).arity > 1
          Origen.log.warning "Configuration in #{config_loc.name} has attribute ##{scope} whose block has an arity > 1"
          Origen.log.warning 'Calls to this attribute from Origen are only given an options hash parameter. Any other arguments are extraneous'
        end

        # Inject the header based on these guidelines:
        # 1. if pattern_header is nil, ignore all. Don't print he message, don't do anything.
        # 2. if pattern header is a block, print the message, then call the block. This allows the user to format everything themselves.
        #    i.e., use of cc, ss, etc. is allowed here, at the expense of the user being responsible for the formatting.
        # 3. if a string, print the message and format the string as 'cc'
        # 4. if an array, print the message and format the array as a subsequent 'cc' calls.
        injection = config_loc.config.send(scope).call({})
        if injection.nil?
          # Do nothing. It is assumed in this acase that the pattern header has not comments to add at this scope.
          return
        elsif injection.is_a?(String)
          c2(' ' * message_spacing + message)
          c2(' ' * line_spacing + injection.to_s)
          inject_separator(options) unless no_separator
        elsif injection.is_a?(Array)
          c2(' ' * message_spacing + message)
          injection.each do |line|
            c2(' ' * line_spacing + line.to_s)
          end
          inject_separator(options) unless no_separator
        elsif injection.respond_to?(:call)
          c2(' ' * message_spacing + message)
          injection.call
          inject_separator(options) unless no_separator
        else
          Origen.app.fail!(message: "Unexpected object class returned by config.pattern_header from #{config_loc.name}: #{injection.class}", exception_class: TypeError)
        end
      end

      def pattern_open(options = {})
        options = {
          call_startup_callbacks: true
        }.merge(options)

        iterators = options.delete(:iterators) || []

        args = options.delete(:args)

        if Origen.tester.generate?
          # Now the pattern name is established delete any existing versions of this pattern
          # to make it clearer that something has gone wrong if there is an error generating the new one
          unless job.test?
            File.delete(job.output_pattern) if File.exist?(job.output_pattern)

            unless tester.try(:sim?)
              log.info "Generating...  #{job.output_pattern_directory}/#{job.output_pattern_filename}".ljust(50)
            end
          end
        end

        Origen.tester.inhibit_comments = job.no_comments? if Origen.tester.respond_to?(:inhibit_comments=)

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
            Origen.app.listeners_for(:startup).each do |listener|
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
            Origen.app.listeners_for(:shutdown, top_level: :last).each do |listener|
              listener.shutdown(options)
            end
          end
          ss 'Pattern complete'

          # Now the pattern has run call the render method if the tester uses a template
          Origen.tester.render_template
          Origen.tester.render_body
        end

        bank = options[:inhibit] ? :null : :footer
        stage.with_bank bank do
          Origen.tester.pattern_footer(options)
          Origen.tester.render_footer
        end

        # Generate the pattern header, do this at the very end so that it can
        # dynamically pick up what import subs are required and things like that
        if Origen.tester.generate?
          bank = options[:inhibit] ? :null : :header
          stage.with_bank bank do
            header
            options[:pattern] = job.output_pattern_filename.sub(job.output_extension, '') # remove output extension
            Origen.tester.pattern_header(options)
            Origen.tester.render_header
          end
        end

        unless options[:inhibit] || !Origen.tester.generate? || job.test?
          stats.collect_for_pattern(job.output_pattern) do
            # If the tester is going to deal with writing out the final pattern. The use case for this is when
            # the pattern is comprised of multiple files instead of the more conventional case here which each
            # pattern is one file.
            if tester.respond_to?(:open_and_write_pattern)
              tester.open_and_write_pattern(job.output_pattern) do
                [:header, :body, :footer].each do |section|
                  Origen.tester.format(stage.bank(section), section)
                end
              end
            else
              File.open(job.output_pattern, 'w') do |f|
                [:header, :body, :footer].each do |section|
                  Origen.tester.format(stage.bank(section), section) do |line|
                    f.puts line
                  end
                end
              end
            end
          end

          unless tester.try(:sim?)
            log.info ' '
            log.info "Pattern vectors: #{stats.number_of_vectors_for(job.output_pattern).to_s.ljust(10)}"
            log.info 'Execution time'.ljust(15) + ': %.6f' % stats.execution_time_for(job.output_pattern)
            log.info '----------------------------------------------------------------------'
            check_for_changes(job.output_pattern, job.reference_pattern) unless tester.try(:disable_pattern_diffs)
          end
          if @pattern_sequence
            @pattern_sequence.send(:log_execution_profile)
          end
          stats.record_pattern_completion(job.output_pattern)
        end

        if Origen.tester.generate?
          Origen.app.listeners_for(:pattern_generated).each do |listener|
            if listener.class.instance_method(:pattern_generated).arity == 1
              listener.pattern_generated(Pathname.new(job.output_pattern))
            else
              listener.pattern_generated(Pathname.new(job.output_pattern), job.options)
            end
          end
        end
      end
    end
  end
end
