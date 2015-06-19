module RGen
  module Tester
    class Ultraflex
      class Parser
        class PatternSet
          class Pattern
            attr_accessor :parser

            ATTRS = %w(pattern_set file_name start_label stop_label comment)

            ALIASES = {
              pattern: :file_name,
              file:    :file_name,
              name:    :file_name
            }

            # Generate readers for all attributes and their aliases
            ATTRS.each do |attr|
              attr_reader attr.to_sym
            end

            ALIASES.each do |_alias, attr|
              define_method("#{_alias}") do
                send(attr)
              end
            end

            def initialize(line)
              @line = line
              parse
              if valid?
                ATTRS.each_with_index do |attr, i|
                  instance_variable_set("@#{attr}", components[i + 1])
                end
              end
            end

            def parse
              @components = @line.split("\t") unless @line.strip.empty?
            end

            def valid?
              components[1] && !components[1].empty? && components[1] != 'Pattern Set' &&
                components[2] && !components[2].empty?
            end

            def components
              @components ||= []
            end
          end

          def initialize(line, options = {})
            @parser = options[:parser]
            p = add_pattern_line(line)
            @name = p.pattern_set if p.valid?
          end

          def inspect  # :nodoc:
            "<PatternSet: #{name}>"
          end

          def name
            @name
          end

          def patterns
            @patterns ||= []
          end

          def self.extract_name(line)
            new(line).name
          end

          def add_pattern_line(line)
            p = Pattern.new(line)
            patterns << Pattern.new(line) if p.valid?
            p
          end

          def valid?
            patterns.all?(&:valid?)
          end

          # Returns an array containing all pattern names contained in this
          # pattern set
          def pattern_names
            # This removes the path and extensions
            patterns.map { |pat| pat.name.gsub(/.*[\\\/]/, '').gsub(/\..*/, '') }
          end
        end
      end
    end
  end
end
