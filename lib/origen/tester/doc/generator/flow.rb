module Origen
  module Tester
    class Doc
      module Generator
        class Flow
          include Origen::Tester::Generator
          include Origen::Tester::Generator::FlowControlAPI

          OUTPUT_POSTFIX = 'flow'
          OUTPUT_EXTENSION = 'yaml'

          def add(type, options = {})
            preserve_comments = options.delete(:preserve_comments)
            line = track_relationships(options) do |options|
              FlowLine.new(type, options)
            end
            collection << line unless Origen.interface.resources_mode?
            if preserve_comments
              line.description = Origen.interface.doc_comments
            else
              line.description = Origen.interface.doc_comments_consume
            end
            line
          end

          def start_section(options = {})
            l = FlowLine.new(:section_start, options)
            if options[:name]
              desc = [options[:name]]
            else
              desc = []
            end
            l.description = desc + Origen.interface.doc_comments_consume
            collection << l
          end

          def stop_section(options = {})
            collection << FlowLine.new(:section_stop, options)
          end

          def test(instance, options = {})
            options = save_context(options)
            add(:test, { test: instance }.merge(options))
          end

          def set_device(options = {})
            add(:set_device, options)
          end

          def to_yaml(options = {})
            collection.map { |l| l.to_yaml(options) }
          end

          def render(file, options = {})
            options[:file] = file
            add(:render, options)
          end

          def skip(identifier = nil, options = {})
            identifier, options = nil, identifier if identifier.is_a?(Hash)
            identifier = generate_unique_label(identifier)
            options[:test] = identifier
            add(:branch, options)
            yield
            add(:label, test: identifier)
          end
        end
      end
    end
  end
end
