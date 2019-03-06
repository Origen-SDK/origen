require 'pathname'

module Origen
  # All logic for working with files/directories and resolving path names
  # should be included here.
  #
  # An instance of this class is available as Origen.file_handler
  #
  # Some portions of Origen may implement local code to do this, but these
  # should all be transitioned to use this over time.
  class FileHandler
    attr_accessor :default_extension

    # Returns an array of file/pattern names lines from a list file.
    # This will also take care of recursively expanding any embedded
    # list references.
    def expand_list(files, options = {})
      options = {
        preserve_duplicates: tester && tester.try(:sim?)
      }.merge(options)
      list_of_files = [files].flatten.map do |file|
        f = file.strip
        # Takes care of blank or comment lines in a list file
        if f.empty? || f =~ /^\s*#/
          nil
        # Don't expand program lists when submitting to lsf,
        # there are likely to be relational dependencies between
        # flows meaning that they must be generated together
        elsif is_a_list?(f) && !(options[:lsf] && options[:action] == :program)
          expand_list(open_list(f), options)
        else
          f
        end
      end.flatten.compact
      if options[:preserve_duplicates]
        list_of_files
      else
        list_of_files.uniq
      end
    end

    # Returns the contents of the given list file in an array, if it
    # can be found, if not will raise an error
    def open_list(file)
      f = clean_path_to(file, allow_missing: true)
      if f
        f = File.open(f, 'r')
      elsif File.exist?("#{Origen.root}/list/#{File.basename(file)}")
        f = File.open("#{Origen.root}/list/#{File.basename(file)}", 'r')
      elsif @last_opened_list_dir && File.exist?("#{@last_opened_list_dir}/#{file}")
        f = File.open("#{@last_opened_list_dir}/#{file}", 'r')
      else
        fail "Could not find list file: #{file}"
      end
      lines = f.readlines
      f.close
      # Before we go save the directory of this list, this will help
      # us to resolve any relative path references to other lists that
      # it may contain
      @last_opened_list_dir = clean_path_to(Pathname.new(f).dirname)
      lines
    end

    # Returns true if the input argument is a list, for now this is
    # simply defined by the filename ending in .list
    def is_a_list?(file)
      !!(file =~ /list$/)
    end

    # Yields absolute paths to the given file or directory. If a directory is supplied
    # the method will recurse into the sub directories and ultimately yield
    # every file contained within the directory and its children.
    def resolve_files(file_or_dir_path, options = {}, &block)
      options = {
        # Set to :template when calling to consider references to template
        # files from an import library
        import: false
      }.merge(options)
      [file_or_dir_path].flatten.each do |file_or_dir_path|
        path = inject_import_path(file_or_dir_path, type: options[:import]) if options[:import]
        path = clean_path_to(file_or_dir_path, options)
        self.base_directory = path unless options[:internal_call]
        if path.directory?
          Dir.glob("#{path}/*").sort.each do |file|
            resolve_files(file, { internal_call: true }.merge(options), &block)
          end
        else
          # Ignore files with the given prefix if supplied, but only if this is a file that
          # has been found, if explicitly asked to compile a file from the caller do it regardless
          if options[:ignore_with_prefix] && options[:internal_call]
            return nil if path.basename.to_s =~ /^#{options[:ignore_with_prefix]}/
          end
          yield path
        end
      end
    end

    # Returns a full path to the given file or directory, raises an error if it
    # can't be resolved
    def clean_path_to(file, options = {})
      # Allow individual calls to this method to specify additional custom load paths to consider
      if options[:load_paths]
        [options[:load_paths]].each do |root|
          if File.exist?("#{root}/#{file}")
            return Pathname.new("#{root}/#{file}")
          end
        end
      end
      if File.exist?(file)
        if Pathname.new(file).absolute?
          Pathname.new(file)
        else
          Pathname.new("#{Pathname.pwd}/#{file}")
        end
      # Is it a relative reference within a list file?
      elsif @last_opened_list_dir && File.exist?("#{@last_opened_list_dir}/#{file}")
        Pathname.new("#{@last_opened_list_dir}/#{file}")
      # Is it a relative reference to the current base directory?
      elsif File.exist?("#{base_directory}/#{file}")
        Pathname.new("#{base_directory}/#{file}")
      # Is it a path relative to Origen.root?
      elsif File.exist?("#{Origen.root}/#{file}")
        Pathname.new("#{Origen.root}/#{file}")
      # Is it a path relative to the current directory?
      elsif current_directory && File.exist?("#{current_directory}/#{file}")
        Pathname.new("#{current_directory}/#{file}")
      # Is it a path relative to the current plugin's Origen.root?
      elsif Origen.app.plugins.current && File.exist?("#{Origen.app.plugins.current.root}/#{file}")
        Pathname.new("#{Origen.app.plugins.current.root}/#{file}")
      elsif options[:default_dir]
        m = all_matches(file, options)
        if m
          Pathname.new(m)
        else
          if options[:allow_missing]
            return nil
          else
            fail "Can't find: #{file}"
          end
        end
      else
        if options[:allow_missing]
          return nil
        else
          fail "Can't find: #{file}"
        end
      end
    end

    def check(path)
      file_plugin = Origen.app.plugins.path_within_a_plugin(path)
      if file_plugin
        if Origen.app.plugins.current
          if file_plugin == Origen.app.plugins.current.name
            return path
          else
            puts "The requested file is from plugin #{file_plugin} and current system plugin is set to plugin #{Origen.app.plugins.current.name}!"
            fail 'Incorrect plugin error!'
          end
        else
          Origen.app.plugins.temporary = file_plugin
          return path
        end
      else
        return path
      end
    end

    def all_matches(file, options)
      if Origen.app.plugins.current
        matches = Dir.glob("#{options[:default_dir]}/#{Origen.app.plugins.current.name}/**/#{file}").sort
        matches = matches.flatten.uniq
        if matches.size == 0
          matches = Dir.glob("#{options[:default_dir]}/**/#{file}").sort
          matches = matches.flatten.uniq
        end
      else
        matches = (Dir.glob("#{options[:default_dir]}/**/#{file}") + # Avoids symlinks
                    Dir.glob("#{options[:default_dir]}/#{file}")).sort
        if matches.size == 0
          matches = Dir.glob("#{options[:default_dir]}/**{,/*/**}/#{file}").sort # Takes symlinks into consideration
        end
        matches = matches.flatten.uniq
      end

      if matches.size == 0
        return nil
      elsif matches.size > 1
        puts 'The following matches were found:'
        puts matches
        fail "Ambiguous file #{file}"
      else
        return check(matches.first)
      end
    end

    # Returns an absolute path for the given
    def relative_to_absolute(path)
      if Pathname.new(path).absolute?
        Pathname.new(path)
      else
        Pathname.new("#{Pathname.pwd}/#{path}")
      end
    end

    def relative_path_to(path)
      clean_path_to(path).relative_path_from(Pathname.pwd)
    end

    def clean_path_to_sub_template(file)
      if File.exist?(file)
        if Pathname.new(file).absolute?
          return Pathname.new(file)
        else
          return Pathname.new("#{Pathname.pwd}/#{file}")
        end
      end
      file = inject_import_path(file, type: :template)
      file = add_underscore_to(file)
      file = add_extension_to(file)
      web_file = file =~ /\.(html|md)(\.|$)/
      begin
        # Allow relative references to templates/web when compiling a web template
        if Origen.lsf.current_command == 'web' || web_file
          clean_path_to(file, load_paths: "#{Origen.root}/templates/web")
        else
          clean_path_to(file)
        end
      rescue
        # Try again without .erb
        file = file.gsub('.erb', '')
        if Origen.lsf.current_command == 'web' || web_file
          clean_path_to(file, load_paths: "#{Origen.root}/templates/web")
        else
          clean_path_to(file)
        end
      end
    end

    def clean_path_to_template(file)
      file = inject_import_path(file, type: :template)
      file = add_extension_to(file)
      clean_path_to(file)
    end

    # If the current path looks like it is a reference to an import, the
    # path will be replaced with the absolute path to the local import directory
    def inject_import_path(path, options = {})
      path = path.to_s unless path.is_a?(String)
      if path =~ /(.*?)\/.*/
        import_name = Regexp.last_match[1].downcase.to_sym
        if import_name == :origen || import_name == :origen_core || Origen.app.plugins.names.include?(import_name) ||
           import_name == :doc_helpers
          # Special case to allow a shortcut for this common import plugin and to also handle legacy
          # code from when it was called doc_helpers instead of origen_doc_helpers
          if import_name == :doc_helpers
            root = Origen.app(:origen_doc_helpers).root
          else
            unless import_name == :origen || import_name == :origen_core
              root = Origen.app(import_name).root
            end
          end
          if options[:type] == :template
            if import_name == :origen || import_name == :origen_core
              path.sub! 'origen', "#{Origen.top}/templates/shared"
            else
              path.sub! Regexp.last_match[1], "#{root}/templates/shared"
            end
          else
            fail 'Unknown import path type!'
          end
        end
      end
      path
    end

    def clean_path_to_sub_program(file)
      file = add_underscore_to(file)
      file = add_rb_to(file)
      clean_path_to(file)
    end

    # Insert _ in file name if not present
    def add_underscore_to(file)
      f = Pathname.new(file)
      if f.basename.to_s =~ /^_/
        file
      else
        "#{f.dirname}/_#{f.basename}"
      end
    end

    def add_rb_to(file)
      f = Pathname.new(file)
      "#{f.dirname}/#{f.basename('.rb')}.rb"
    end

    def add_extension_to(file)
      f = Pathname.new(file)
      if f.basename('.erb').extname.empty?
        if default_extension
          "#{f.dirname}/#{f.basename('.erb')}#{default_extension}.erb"
        else
          "#{f.dirname}/#{f.basename('.erb')}#{Pathname.new(Origen.file_handler.current_file).basename('.erb').extname}.erb"
        end
      else
        "#{f.dirname}/#{f.basename('.erb')}.erb"
      end
    end

    def set_output_directory(options = {})
      options = {
        create: true
      }.merge(options)
      if options[:output]
        @output_directory = relative_to_absolute(options[:output])
      else
        @output_directory = Pathname.new(Origen.config.output_directory)
      end
      if options[:create]
        FileUtils.mkdir_p(@output_directory) unless @output_directory.exist?
      end
      @output_directory
    end

    # Returns an absolute pathname to the current output directory
    def output_directory
      @output_directory ||= set_output_directory
    end

    def set_reference_directory(options = {})
      options = {
        create: true
      }.merge(options)
      if options[:reference]
        @reference_directory = relative_to_absolute(options[:reference])
      else
        @reference_directory = Pathname.new(Origen.config.reference_directory)
        # Create the reference output directory if it does not exist.
        FileUtils.mkdir_p(@reference_directory) unless @reference_directory.exist?
      end
      if options[:create]
        # Delete any broken symlinks in the top level .ref
        dir = "#{Origen.root}/.ref"
        if File.symlink?(dir)
          FileUtils.rm_f(dir) unless File.exist?(dir)
        end
        FileUtils.mkdir_p(@reference_directory) unless @reference_directory.exist?
      end
      @reference_directory
    end

    # Returns an absolute pathname to the current reference directory
    def reference_directory
      @reference_directory ||= set_reference_directory
    end

    # Returns the base directory containing the source files being generated/compiled.
    #
    # When operating on a single file this will return the directory containing that
    # file, when operating on a directory this will return the directory.
    def base_directory
      @base_directory
    end

    def base_directory=(file_or_dir)
      # puts "Base directory changed by: #{caller[0]}"
      if file_or_dir.directory?
        @base_directory = file_or_dir
      else
        @base_directory = file_or_dir.dirname
      end
    end

    def current_directory
      return @current_directory if @current_directory
      @current_directory = clean_path_to(current_file).dirname if current_file
    end

    def current_file=(file)
      @current_directory = nil
      @current_file = file
    end

    def current_file
      @current_file
    end

    def preserve_current_file
      file = current_file
      yield
      self.current_file = file
    end

    def preserve_state
      file = current_file
      dir = base_directory
      output = output_directory
      ref = reference_directory
      ext = default_extension
      yield
      self.base_directory = dir if dir
      self.current_file = file if file
      set_output_directory(output: output) if output
      set_reference_directory(reference: ref) if ref
      self.default_extension = ext
    end

    def preserve_and_clear_state
      file = current_file
      dir = base_directory
      output = output_directory
      ref = reference_directory
      ext = default_extension
      current_file = nil
      base_directory = nil
      output_directory = nil
      reference_directory = nil
      yield
      self.base_directory = dir if dir
      self.current_file = file if file
      set_output_directory(output: output) if output
      set_reference_directory(reference: ref) if ref
      self.default_extension = ext
    end

    # Returns the sub directory of the current base directory that the
    # given file is in
    def sub_dir_of(file, base = base_directory)
      file = Pathname.new(file) unless file.respond_to?(:relative_path_from)
      base = Pathname.new(base) unless base.respond_to?(:relative_path_from)
      rel = file.relative_path_from(base)
      if file.directory?
        rel
      else
        rel.dirname
      end
    end

    # Convenience method to use when you want to write to a file, this takes
    # care of ensuring that the directory exists prior to attempting to open
    # the file
    def open_for_write(path)
      dir = Pathname.new(path).dirname
      FileUtils.mkdir_p(dir) unless File.exist?(dir)
      File.open(path, 'w') do |f|
        yield f
      end
    end
  end
end
