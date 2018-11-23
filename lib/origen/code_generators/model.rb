module Origen
  module CodeGenerators
    class Model < Origen::CodeGenerators::Base
      def self.banner
        'origen new model NAME'
      end

      desc <<-END
This generator creates a model and optionally a controller for it within your application's
lib directory.

The name of the model should be given, in lower case, optionally indicating the presence
of any namespacing you want it to be created under.

Examples:
  origen new model sequencer       # Creates app/lib/my_application/sequencer.rb
  origen new model bist/sequencer  # Creates app/lib/my_application/bist/sequencer.rb
END

      def validate_args
        validate_resource_name(args.first)

        if args.size > 1 || args.size == 0
          msg = "Only one argument is expected by the model generator, e.g. 'origen new model sequencer', 'origen new model bist/sequencer'"
          Origen.log.error(msg)
          exit 1
        end
      end

      def create_model_file
        klass = resource_path_to_class(args.first)
        @namespaces = klass.split('::').map(&:underscore)
        @name = @namespaces.pop
        @namespaces.map! do |namespace|
          begin
            const = namespace.camelcase.constantize
            [const.is_a?(Class) ? :class : :module, namespace]
          rescue NameError
            [:module, namespace]
          end
        end
        @root_class = true
        file = class_name_to_lib_file(klass)
        template 'templates/code_generators/model.rb', file
        if yes? 'Does this model need a controller? (n):'
          file = file.to_s.sub(/\.rb/, '_controller.rb')
          template 'templates/code_generators/controller.rb', file
        end
      end
    end
  end
end
