module Origen
  module Tester
    class V93K
      module Generator
        class PatternMaster
          include Origen::Tester::Generator

          TEMPLATE = "#{Origen.top}/lib/origen/tester/v93k/generator/templates/template.pmfl.erb"

          def add(name, options = {})
            check_for_duplicates(name)
            record_pattern(name)
            p = Pattern.new(name, options)
            collection << p
            p
          end

          # Returns true if the given pattern name has already been added to the current pattern
          # master file.
          #
          # Pass in :global => true for all pattern sets sheets to be considered.
          def duplicate?(name, options = {})
            files = existing_patterns[name]
            if files && !files.empty?
              options[:global] || files.include?(filename)
            else
              false
            end
          end

          private

          def check_for_duplicates(name)
            if duplicate?(name)
              error "Duplicate pattern #{name} generated in #{filename}"
              exit 1
            elsif duplicate?(name, global: true)
              warning "Pattern #{name} is duplicated in: #{existing_patterns[name].join(', ')}"
            end
          end

          def existing_patterns
            @@existing_patterns ||= {}
          end

          def record_pattern(name)
            existing_patterns[name] ||= []
            existing_patterns[name] << filename
          end
        end
      end
    end
  end
end
