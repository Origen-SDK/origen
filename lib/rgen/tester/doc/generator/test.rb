module RGen
  module Tester
    class Doc
      module Generator
        class Test
          attr_accessor :name, :index, :version, :append_version, :attributes

          def initialize(name, attrs = {})
            attrs = {}.merge(attrs)  # Important to keep this to clone the original options
            # so that the caller's copy if not affected by stripping
            # out the flow/relation options
            @attributes = {}
            @append_version = true
            self.name = name
            RGen.interface.extract_relation_options!(attrs)
            RGen.interface.extract_flow_control_options!(attrs)
            attrs.each do |attribute, val|
              @attributes[attribute] = val
            end
          end

          def to_yaml(options = {})
            {
              'attributes' => attributes_to_yaml(options)
            }
          end

          def attributes_to_yaml(_options = {})
            a = {}
            @attributes.each do |name, val|
              a[name.to_s] = val if val
            end
            a['name'] = name
            a
          end

          def method_missing(method, *args, &_block)
            method = method.to_s
            if method.gsub!('=', '')
              @attributes[method] = args.first
            else
              @attributes[method]
            end
          end

          def ==(other_test)
            self.class == other_test.class &&
              unversioned_name.to_s == other_test.unversioned_name.to_s &&
              attributes.size == other_test.attributes.size &&
              attributes.all? { |name, val| other_test.attributes[name] == val }
          end

          def name
            if version && @append_version
              "#{@name}_v#{version}"
            else
              @name.to_s
            end
          end

          def unversioned_name
            @name.to_s
          end
        end
      end
    end
  end
end
