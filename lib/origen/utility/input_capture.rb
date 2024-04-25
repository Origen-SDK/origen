require 'readline'
module Origen
  module Utility
    module InputCapture
      # Gets text input from the user
      # Supply an optional default value in the event that the user enters nothing
      def get_text(options = {})
        options = { default:        false,
                    single:         false, # Set if only a single line entry is expected
                    confirm:        false,
                    accept:         false, # Supply and array of entries you are willing to accept
                    case_sensitive: false, # If accept values are supplied they will be treated as case
                    # in-sensitive by default
                    wrap:           true # Automatically split long lines
        }.merge(options)
        # rubocop:enable Layout/MultilineHashBraceLayout
        if options[:confirm]
          puts "Type 'yes' or 'no' to confirm or 'quit' to abort."
        elsif options[:accept]
          puts "You can enter: #{options[:accept].map { |v| "'#{v}'" }.join(', ')} or 'quit' to abort."
          # "
        else
          puts options[:single] ? "Enter 'quit' to abort." : "Enter a single '.' to finish, or 'quit' to abort."
        end
        puts '------------------------------------------------------------------------------------------'
        text = ''
        line = ''
        if options[:confirm]
          print "(#{options[:default]}): " if options[:default]
        else
          print "Hit return to accept the default (#{options[:default]}): " if options[:default]
        end

        while line != '.'
          orig_line = Readline.readline('', false).chomp.rstrip
          line = orig_line.strip
          if (line.empty? || line == '.') && text.empty? && options[:default]
            text = options[:default].to_s
            line = '.'
          elsif line.downcase == 'quit'
            exit 0
          elsif line == '.'
          # Do nothing
          else
            if options[:wrap]
              split_long_line(orig_line) do |short_line|
                text << "#{short_line}\n"
              end
            else
              text << orig_line
            end
          end
          confirm = text.strip.downcase if options[:confirm]
          text = text.strip if options[:single]
          line = '.' if options[:single] || options[:confirm]
        end
        puts ''

        if options[:confirm]
          if confirm == 'no' || confirm == 'n'
            if options[:confirm] == :return_boolean
              return false
            else
              exit 0
            end
          end
          if confirm == 'yes' || confirm == 'y'
            if options[:confirm] == :return_boolean
              true
            end
          else
            get_text(options)
          end

        elsif options[:accept]
          accept = options[:accept].map do |v|
            v = v.to_s
            v = v.downcase unless options[:case_sensitive]
            v
          end
          text = text.downcase unless options[:case_sensitive]
          text = text.strip
          if accept.include?(text)
            text
          else
            get_text(options)
          end

        else
          text
        end
      end

      # Splits a long line into short ones, split by the nearest space
      def split_long_line(line)
        if line.length <= 90
          yield line
        else
          until line.empty?
            if line.length <= 90
              yield line
              line = ''
            else
              yield line.slice(0, find_space(line, 90))
              line = line.slice(find_space(line, 90), line.length).strip
            end
          end
        end
      end

      # Find the space closest to but less than max_position, returns max_position if none
      # can be found
      def find_space(line, max_position)
        x = max_position
        x -= 1 until line[x] == ' ' || x == 0
        x == 0 ? max_position : x
      end
    end
  end
end
