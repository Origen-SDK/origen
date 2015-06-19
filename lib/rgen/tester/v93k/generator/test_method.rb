module RGen
  module Tester
    class V93K
      module Generator
        class TestMethod
          ATTRS =
            %w(name klass method_name parameters limits
            )

          ALIASES = {
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
