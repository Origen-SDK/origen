module Origen
  module Utility
    module FileDiff
      # Diff Processor (Origen::Utility::Processor) provides an easy way to diff the contents of two files
      # and display the differences as an HTML file or a TXT file.
      # Very basic functionality, but can be expanded to add more features in the future.
      # Comments are not ignored for now (maybe a future enhancement)
      # Each difference is displayed in a different color in the HTML page
      # Legend:
      #       - New: Light Green
      #       - Modified: Light Gray
      #       - Deleted: Pink
      # Usage:
      #       processor = Origen::Utility::FileDiff::Processor.new("#{Origen.root}/left.txt", "#{Origen.root}/right.txt")
      #
      # To Generate a HTML file (diff.html) showing the differences
      #       Origen::Utility::FileDiff::Formatter::Html.new(processor.process!, "#{Origen.root}/diff.html").format
      #
      # To Generate a TXT file (diff.txt) showing the differences
      #       Origen::Utility::FileDiff::Formatter::Text.new(processor.process!, "#{Origen.root}/diff.txt").format

      class InputFile < Array
        attr_accessor :pointer

        def initialize
          self.pointer = 0
        end

        def current_line
          self[pointer]
        end

        def advance_pointer!
          self.pointer += 1
        end

        def find_current_line_in(other)
          index = (other[other.pointer..-1] || []).index(current_line)
          index.nil? ? nil : other.pointer + index
        end
      end

      class OutputFile < Array
        class Line < String
          attr_accessor :type, :original_number
          def initialize(type, input_file)
            self.type = type
            return unless input_file
            replace(input_file.current_line)
            self.original_number = input_file.pointer + 1
            input_file.advance_pointer!
          end
        end

        def add_line(type, input_file = nil)
          push(Line.new(type, input_file))
        end
      end

      class Processor
        attr_accessor :source, :target
        attr_accessor :source_output, :target_output
        def initialize(source_file_name, target_file_name)
          self.source = InputFile.new
          self.target = InputFile.new
          self.source_output = OutputFile.new
          self.target_output = OutputFile.new
          IO.readlines(source_file_name).each do |line|
            source << line
          end
          IO.readlines(target_file_name).each do |line|
            target << line
          end
        end

        def handle_exactly_matched
          source_output.add_line(:unchanged, source)
          target_output.add_line(:unchanged, target)
        end

        def handle_line_changed
          source_output.add_line(:changed, source)
          target_output.add_line(:changed, target)
        end

        def handle_block_added(size)
          size.times do
            source_output.add_line(:added) # Empty line in the left side of the diff
            target_output.add_line(:added, target)
          end
        end

        def handle_block_deleted(size)
          size.times do
            source_output.add_line(:deleted, source)
            target_output.add_line(:deleted)  # Empty line in the right side of the diff
          end
        end

        def process!
          while  source.pointer < source.size && target.pointer < target.size
            matched = source.find_current_line_in(target)
            if matched
              if matched > target.pointer
                deleted = target.find_current_line_in(source)
                handle_block_deleted(deleted - source.pointer) if deleted
              end
              handle_block_added(matched - target.pointer)
              handle_exactly_matched
            else
              found = target.find_current_line_in(source)
              if found
                handle_block_deleted(found - source.pointer)
              else
                handle_line_changed
              end
            end
          end
          handle_block_deleted(source.size - source.pointer)
          handle_block_added(target.size - target.pointer)

          self
        end
      end

      module Formatter
        class Base
          attr_accessor :source_output, :target_output, :file
          def initialize(processed_diff, output_file_name)
            self.source_output = processed_diff.source_output
            self.target_output = processed_diff.target_output
            self.file = File.open(output_file_name, 'w')
          end
        end

        class Html < Base
          def format
            tag(:style) { content('td{vertical-align: middle} pre{margin: 0px} .added{background-color: lightgreen;}.deleted{background-color: pink;}.changed{background-color: lightgray;}.line{background-color: lightblue}') }
            tag :table, cellpaddig: 0, cellspacing: 0 do
              source_output.each_with_index do |src, i|
                tgt = target_output[i]
                tag :tr do
                  tag(:td, class: :line)     { tag(:pre) { content(src.original_number) } }
                  tag(:td, class: src.type)  { tag(:pre) { content(src) } }
                  tag(:td, class: :line)     { tag(:pre) { content(tgt.original_number) } }
                  tag(:td, class: tgt.type)  { tag(:pre) { content(tgt) } }
                end
              end
            end
          end

          private

          def tag(name, options = {}, &block)
            file.puts %(<#{name})
            file.puts options.collect { |attribute, value| %(#{attribute}="#{value}") }
            file.puts '>'
            yield
            file.puts "</#{name}>"
          end

          def content(inner_text)
            file.puts(inner_text.to_s == '' ? '&nbsp;' : inner_text)
          end
        end

        class Text < Base
          def format
            pointer = 0
            while pointer < target_output.size
              size = 1
              type = source_output[pointer].type
              case type
              when :added
                added(pointer,    size = get_block_size(pointer, :added))
              when :deleted
                deleted(pointer,  size = get_block_size(pointer, :deleted))
              when :changed
                changed(pointer,  size = get_block_size(pointer, :changed))
              end
              file.puts unless type == :unchanged
              pointer += size
            end
          end

          private

          def get_block_size(pointer, type)
            size = 1
            size += 1 while target_output[pointer + size].type == type
            size
          end

          def added(pointer, size)
            file.puts(target_output[pointer].original_number)
            0.upto(size - 1) { |i| file.puts("+ #{target_output[pointer + i]}") }
          end

          def deleted(pointer, size)
            file.puts(source_output[pointer].original_number)
            0.upto(size - 1) { |i| file.puts("- #{source_output[pointer + i]}") }
          end

          def changed(pointer, size)
            file.puts("#{source_output[pointer].original_number},#{target_output[pointer].original_number}")
            0.upto(size - 1) { |i| file.puts("source<< #{source_output[pointer + i]}") }
            file.puts('=======')
            0.upto(size - 1) { |i| file.puts("target>> #{target_output[pointer + i]}") }
          end
        end
      end
    end
  end
end
