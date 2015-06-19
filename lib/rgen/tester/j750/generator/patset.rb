module RGen
  module Tester
    class J750
      module Generator
        class Patset
          attr_accessor :index

          class Pattern
            ATTRS = %w(pattern_set file_name start_label stop_label comment)

            ALIASES = {
              pattern: :file_name
            }

            DEFAULTS = {
            }

            # Generate accessors for all attributes and their aliases
            ATTRS.each do |attr|
              attr_accessor attr.to_sym
            end

            ALIASES.each do |_alias, val|
              define_method("#{_alias}=") do |v|
                send("#{val}=", v)
              end
              define_method("#{_alias}") do
                send(val)
              end
            end

            def initialize(patset, attrs = {})
              # Set the defaults
              DEFAULTS.each do |k, v|
                send("#{k}=", v)
              end
              # Then the values that have been supplied
              self.pattern_set = patset
              attrs.each do |k, v|
                send("#{k}=", v)
              end
            end

            def to_s
              l = "\t"
              ATTRS.each do |attr|
                l += "#{send(attr)}\t"
              end
              "#{l}"
            end
          end

          # Specify multiple patterns by passing an array of attributes
          # as the 2nd argument:
          #
          #   Patset.new("mrd1_pset", :pattern => "nvm_mrd1.PAT")
          #
          #   Patset.new("mrd1_pset", [{:pattern => "nvm_mrd1.PAT"},
          #                            {:pattern => "nvm_global_subs.PAT, :start_label => "subr"}
          #                           ])
          def initialize(name, attrs = {})
            attrs = [attrs] unless attrs.is_a? Array
            attrs.each do |pattrs|
              if pattrs[:pattern]
                pat = Pathname.new(pattrs[:pattern].gsub('\\', '/')).basename('.*').to_s
                RGen.interface.referenced_patterns << pat
              end
              lines << Pattern.new(name, pattrs)
            end
            self.name = name
          end

          def ==(other_patset)
            self.class == other_patset.class &&
              name.to_s == other_patset.name.to_s &&
              sorted_pattern_files == other_patset.sorted_pattern_files
          end

          def name
            @name
          end

          def name=(n)
            @name = n
            lines.each { |l| l.pattern_set = n }
            n
          end

          # Returns all lines in the pattern set
          def lines
            @lines ||= []
          end

          # Returns all pattern files in the pattern set in alphabetical order
          def sorted_pattern_files
            @lines.map(&:file_name).sort
          end

          # Returns the fully formatted pattern set for insertion into a patset sheet
          def to_s
            l = ''
            lines.each do |line|
              l += "#{line}\r\n"
            end
            l.chomp
          end
        end
      end
    end
  end
end
