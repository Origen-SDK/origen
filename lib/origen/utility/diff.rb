module Origen
  module Utility
    # Diff provides an easy way to diff the contents of two files while optionally
    # ignoring any differences in file comments.
    #
    #   differ = Origen::Utility::Diff.new(:ignore_blank_lines => true, :comment_char => "//")
    #
    #   differ.file_a = "#{Origen.root}/my/file1.v"
    #   differ.file_b = "#{Origen.root}/my/file2.v"
    #
    #   if differ.diffs?
    #     puts "You've changed something!"
    #   end
    class Diff
      # Full path to File A, this attribute must be set before calling any diff actions
      attr_accessor :file_a
      # Full path to File B, this attribute must be set before calling any diff actions
      attr_accessor :file_b
      # When true the diff will ignore blank lines, or lines that contain only whitespace
      attr_accessor :ignore_blank_lines
      # Set this attribute to the comment char used by the given file and comments will
      # be ignored by the diff.
      # An array of strings can be passed in to mask multiple comment identifiers.
      attr_accessor :comment_char

      # Create a new diff, attributes can be initialized via the options, or can be
      # set later.
      def initialize(options = {})
        @file_a = options[:file_a]
        @file_b = options[:file_b]
        @ignore_blank_lines = options[:ignore_blank_lines]
        @comment_char = options[:comment_char]
        @suspend_string = options[:suspend_string] # permits suspending diff check based on a string
        @resume_string  = options[:resume_string]  # permits resuming diff check based on a string
        @suspend_diff = false
        @resume_diff = false
      end

      # Returns true if there are differences between the two files based on the
      # current configuration
      def diffs?
        initialize_counters
        result = false
        content_a = File.readlines(@file_a)
        content_b = File.readlines(@file_b)

        changes = false
        lines_remaining = true

        while lines_remaining
          a = get_next_line_a(content_a)   # Get the next vectors
          b = get_next_line_b(content_b)
          if !a && !b       # If both patterns finished
            lines_remaining = false
          elsif !a || !b    # If only 1 pattern finished
            lines_remaining = false
            changes = true unless @suspend_diff     # There are extra vectors in one of the patterns
          elsif a != b      # If the vectors don't match
            changes = true unless @suspend_diff
          end
          if @resume_diff # resume checking diffs for subsequent lines
            @suspend_diff = false
            @resume_diff = false
          end
        end

        changes
      end

      private

      def set_suspend_diff(line)
        if line.valid_encoding?
          if @suspend_string && !@suspend_diff
            if line =~ /#{@suspend_string}/
              @suspend_diff = true
            end
          elsif @resume_string && @suspend_diff
            if line =~ /#{@resume_string}/
              @resume_diff = true
            end
          end
        end
      end

      def get_next_line_b(array)
        @b_ix = next_index(array, @b_ix)
        get_line(array, @b_ix)
      end

      def get_next_line_a(array)
        @a_ix = next_index(array, @a_ix)
        get_line(array, @a_ix)
      end

      # Fetches the line from the given array and does some pre-processing
      def get_line(array, ix)
        line = array[ix]
        if line
          set_suspend_diff(line)
          if @comment_char
            # Screen off any inline comments at the end of line
            begin
              [@comment_char].flatten.each do |_char|
                if line =~ /(.*)#{@char}.*/
                  return Regexp.last_match[1].strip
                end
              end
            # This rescue is a crude way to guard against non-ASCII files that find
            # their way in here
          rescue
            return line
            end
          else
            line.strip
          end
        end
      end

      # Find the next line in the given array and return the new index pointer
      def next_index(array, ix = nil)
        ix = ix ? ix + 1 : 0
        matched = false
        while !matched && ix < array.size
          begin
            comment_matched = false
            # Skip comment lines
            if @comment_char
              [@comment_char].flatten.each do |char|
                if array[ix] =~ /^\s*#{char}.*/
                  comment_matched = true
                end
              end
            end
            # Skip blank lines
            if comment_matched
              ix += 1
            elsif @ignore_blank_lines && array[ix] =~ /^\s*$/
              ix += 1
            else
              matched = true
            end
        # This rescue is a crude way to guard against non-ASCII files that find
        # there way in here
        rescue
          matched = true
          end
        end
        ix
      end

      def initialize_counters
        @a_ix = nil
        @b_ix = nil
      end
    end
  end
end
