module RGen
  module Tester
    class V93K
      module Generator
        class TestSuite
          ATTRS =
            %w(name tim_equ_set lev_equ_set tim_spec_set lev_spec_set timset levset
               seqlbl testf test_number
            )

          ALIASES = {
            pattern:        :seqlbl,
            sequence_label: :seqlbl,
            test_num:       :test_number,
            test_function:  :testf,
            levels:         :levset,
            timeset:        :timset,
            time_set:       :timset
          }

          DEFAULTS = {
          }

          # Generate accessors for all attributes and their aliases
          ATTRS.each do |attr|
            attr_accessor attr.to_sym
          end

          # Define the aliases
          ALIASES.each do |_alias, val|
            define_method("#{_alias}=") do |v|
              send("#{val}=", v)
            end
            define_method("#{_alias}") do
              send(val)
            end
          end

          def initialize(name, attrs = {})
            self.name = name
            # Set the defaults
            DEFAULTS.each do |k, v|
              send("#{k}=", v)
            end
            # Then the values that have been supplied
            attrs.each do |k, v|
              send("#{k}=", v)
            end
          end
        end
      end
    end
  end
end
