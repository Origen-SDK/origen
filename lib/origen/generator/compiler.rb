module Origen
  class Generator
    class Compiler # :nodoc: all
      require 'fileutils'
      require 'erb'
      require 'pathname'
      require "#{Origen.top}/helpers/url"

      include Helpers
      include Comparator
      include Renderer

      # During a compile this will return the current top-level file being compiled
      #
      # @example
      #   Origen.generator.compiler.current_file   # => Pathname
      attr_reader :current_file

      # Where compile will place the compiled content in an output file, this method will return
      # it as a string to the caller (i.e. without creating an output file)
      #
      # It expects an absolute path to a single template file as the file argument.
      #
      # @api private
      def compile_inline(file, options = {})
        initial_options = options.merge({})
        options = {
          check_for_changes: false,
          sub_template:      false,
          collect_stats:     false,
          initial_options:   initial_options
        }.merge(options)
        @scope = options[:scope]
        file = Pathname.new(file) unless options[:string]
        run_erb(file, options).strip
      end

      # Compile all files found under the source directory, non-erb files will be copied
      # to the destination un-altered
      def compile(file_or_dir, options = {})
        options = {
          check_for_changes:  true,
          sub_template:       false,
          collect_stats:      true,
          ignore_blank_lines: true
        }.merge(options)
        @scope = options[:scope]
        # Doing here so the output_directory (requiring target load) doesn't get hit if
        # it is already defined
        options[:output_directory] ||= output_directory
        @check_for_changes = options[:check_for_changes]
        @options = options
        if options[:sub_template]
          block = options.delete(:block)
          if is_erb?(file_or_dir)
            run_erb(file_or_dir, options, &block)
          else
            f = File.open(file_or_dir)
            content = f.read
            f.close
            insert(content)
          end
        else
          Origen.file_handler.resolve_files(file_or_dir, ignore_with_prefix: '_', import: :template) do |file|
            compile_file(file, options)
          end
        end
      end

      def merge(file_or_dir, options = {})
        # Compile an up to date reference
        compile(file_or_dir_path, check_for_changes: false, output_directory: merge_reference_directory)
        diffs = []
        Origen.file_handler.resolve_files(file_or_dir, ignore_with_prefix: '_') do |file|
          diffs << merge_file(file, options)
        end
        diffs.compact!
        puts ''
        if diffs.size > 0
          puts 'The following differences are present in the compiled files and must be resolved manually:'
          puts ''
          diffs.each do |diff|
            puts diff
          end
          puts ''
        else
          puts 'Merged successfully!'
        end
      end

      def stats
        Origen.app.stats
      end

      # Compile the supplied file if it is an erb template writing the compiled
      # version to the destination directory.
      # If the file is not an erb template it is simply copied un-altered to the
      # destination directory.
      # File must be an absolute path to the file.
      def compile_file(file, options = {})
        @current_file = Pathname.new(file)
        # This is used when templates are compiled through a test program, but can
        # be problematic when used to compile files standalone. In practice this may
        # not be an issue except when testing Origen and generating and compiling within
        # the same thread, but clearing this here doesn't seem to do any harm.
        Origen.file_handler.default_extension = nil
        begin
          Origen.log.info "Compiling... #{relative_path_to(file)}" unless options[:quiet]
        rescue
          Origen.log.info "Compiling... #{file}" unless options[:quiet]
        end
        Origen.log.info "  Created... #{relative_path_to(output_file(file, options))}" unless options[:quiet]
        stats.completed_files += 1 if options[:collect_stats]
        if is_erb?(file)
          output = run_erb(file, options)
          f = output_file(file, options).to_s
          if output.is_a?(Pathname)
            FileUtils.mv output.to_s, f
          else
            File.open(f, 'w') { |out| out.puts output }
          end
        else  # Just copy it across
          out = output_file(file, options)
          # Delete the target if it already exists, this prevents permission denied errors when copying
          FileUtils.rm_f(out.to_s) if File.exist?(out.to_s)
          FileUtils.cp(file.to_s, out.dirname.to_s)
        end
        if options[:zip]
          `gzip -f -9 #{output_file(file, options)}`
        else
          if @check_for_changes
            check_for_changes(output_file(file, options), reference_file(file, options),
                              comment_char: Origen.app.tester ? Origen.app.tester.program_comment_char : nil,
                              compile_job:  true, ignore_blank_lines: options[:ignore_blank_lines])
          end
        end
      end

      def run_erb(file, opts = {}, &block)
        # Refresh the target to start all settings from scratch each time
        # This is an easy way to reset all registered values
        if opts[:preserve_target]
          options[:preserve_target] = opts.delete(:preserve_target)
        end
        Origen.app.reload_target! unless options[:preserve_target]
        # Record the current file, this can be used to resolve any relative path
        # references in the file about to be compiled
        Origen.file_handler.current_file = file
        # Make the file and options available to the template
        if opts[:initial_options] || opts[:options]
          options.merge!(opts.delete(:initial_options) || opts.delete(:options))
        end
        options[:file] = file
        options[:top_level_file] = current_file
        b = _get_binding(opts, &block)
        if opts[:string]
          content = file
          @current_buffer = '@_string_template'
          buffer = @current_buffer
        else
          content = File.read(file.to_s)
          buffer = buffer_name_for(file)
        end
        if block_given?
          content = ERB.new(content, 0, '%<>', buffer).result(b)
        else
          content = ERB.new(content, 0, Origen.config.erb_trim_mode, buffer).result(b)
        end
        insert(content)
      end

      # @api private
      def _get_binding(opts, &block)
        # Important, don't declare any local variable called options here,
        # the scope of this method will be the default for any templates and
        # we want options to refer to the global options method
        b = opts[:binding] || opts[:scope] || binding
        # If an object has been supplied as the scope, then do some tricks
        # to get a hold of its internal scope
        unless b.is_a?(Binding)
          b.define_singleton_method :_get_binding do |local_opts, &_block|
            # rubocop:disable Lint/UselessAssignment
            options = local_opts
            # rubocop:enable Lint/UselessAssignment
            binding
          end
          # Here the global options, the ones visible right now, are passed to into the method defined above,
          # they will get assigned to the local variable called option and that is what the template will
          # be able to see
          b = b._get_binding(options, &block)
        end
        b
      end

      def current_buffer
        (@scope || self).instance_variable_get(@current_buffer || '@_anonymous')
      end

      def current_buffer=(text)
        (@scope || self).instance_variable_set(@current_buffer || '@_anonymous', text)
      end

      # Returns the ERB buffer name for the given file, something like "@my_file_name"
      def buffer_name_for(file)
        expected_filename = file.basename.to_s.chomp('.erb')
        expected_filename.gsub!('-', '_') if expected_filename.match(/-/)
        expected_filename.gsub!('.', '_') if expected_filename.match(/./)
        @current_buffer = '@_' + expected_filename
      end

      def merge_file(file, _options = {})
        file = Pathname.new(file)
        Origen.log.info "Merging... #{file.basename}"
        if is_erb?(file) && File.exist?(output_file(file))
          check_for_differences(output_file(file), merge_ref_file(file), file)
        elsif File.exist?(output_file(file))
          if check_for_differences(output_file(file), merge_ref_file(file), file)
            FileUtils.cp(output_file(file), file.dirname.to_s)
          end
        end
      end

      def display_path_to(file)
        p = relative_path_to(file).to_s
        p.gsub!('/', '\\') if Origen.running_on_windows?
        p
      end

      def check_for_differences(a, b, file)
        if check_for_changes(a, b, comment_char: ["'", 'logprint'], quiet: true, compile_job: true)
          puts "*** CHANGE DETECTED *** To rollback:  #{Origen.config.copy_command} #{display_path_to(b)} #{display_path_to(a)}"
          "#{Origen.config.diff_command} #{display_path_to(a)} #{display_path_to(b)} & #{ENV['EDITOR']} #{file.cleanpath} &"
        end
      end

      # Returns true if the supplied file name has a .erb extension
      def is_erb?(file)
        !!(file.to_s =~ /.erb$/) || !Origen.config.compile_only_dot_erb_files
      end

      def output_directory
        Origen.file_handler.output_directory
      end

      def reference_directory
        Origen.file_handler.reference_directory
      end

      def merge_reference_directory
        "#{Origen.root}/.merge_ref"
      end

      # Returns the output file corresponding to the given source file, the destination
      # directory will be created if it doesn't exist.
      def output_file(file, options = {})
        options = {
          output_directory: output_directory
        }.merge(options)
        # return @output_file if @output_file
        sub_dir = options[:output_sub_dir] || Origen.file_handler.sub_dir_of(file).to_s
        sub_dir = nil if sub_dir == '.'
        filename = options[:output_file_name] || file.basename.to_s.gsub('.erb', '')
        # filename.gsub!('target', $target.id) if filename =~ /target/ && $target.id
        output = Pathname.new("#{options[:output_directory]}#{sub_dir ? '/' + sub_dir : ''}/#{filename}")
        FileUtils.mkdir_p(output.dirname.to_s) unless File.exist?(output.dirname.to_s)
        # @output_file = output
        output
      end

      # Returns the reference file corresponding to the given source file, the destination
      # directory will be created if it doesn't exist.
      def reference_file(file, options = {})
        # return @reference_file if @reference_file
        sub_dir = Origen.file_handler.sub_dir_of(file).to_s
        sub_dir = nil if sub_dir == '.'
        filename = options[:output_file_name] || file.basename.to_s.gsub('.erb', '')
        # filename.gsub!('target', $target.id) if filename =~ /target/ && $target.id
        reference = Pathname.new("#{reference_directory}#{sub_dir ? '/' + sub_dir : ''}/#{filename}")
        FileUtils.mkdir_p(reference.dirname.to_s) unless File.exist?(reference.dirname.to_s)
        # @reference_file = reference
        reference
      end

      def merge_ref_file(file, options = {})
        options = {
          directory: merge_reference_directory
        }.merge(options)
        # return @merge_ref_file if @merge_ref_file
        sub_dir = Origen.file_handler.sub_dir_of(file).to_s
        sub_dir = nil if sub_dir == '.'
        filename = file.basename.to_s.gsub('.erb', '')
        # filename.gsub!('target', $target.id) if filename =~ /target/ && $target.id
        output = Pathname.new("#{options[:directory]}#{sub_dir ? '/' + sub_dir : ''}/#{filename}")
        FileUtils.mkdir_p(output.dirname.to_s) unless File.exist?(output.dirname.to_s)
        # @merge_ref_file = output
        output
      end
    end
  end
end
