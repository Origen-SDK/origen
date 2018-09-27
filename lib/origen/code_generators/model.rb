module Origen
  module CodeGenerators
    class Model < Origen::CodeGenerators::Base
      desc <<-END
This generator creates a model and associated resources for it, e.g. a controller.

The name of the model should be given, in lower case, optionally indicating the presence
of any namespacing within your applicat
END

      def extract_model_name
        if args.size > 1 || args.size == 0
          msg = args.size > 1 ? 'Only one' : 'One '
          msg << "argument is expected by the model generator, e.g. 'origen new model my_adc', 'origen new model my_blocks/my_block'"
          Origen.log.error(msg)
          exit 1
        end

        @namespaces = ARGV.first.downcase.split('/')

        @name = @namespaces.pop

        @namespaces.unshift(Origen.app.name.to_s) unless @namespaces.first == Origen.app.name.to_s
      end

      def create_model_file
        # @summary = ask 'Describe your plugin in a few words:'
        # template 'templates/code_generators/gemspec.rb', File.join(Origen.root, "#{Origen.app.name}.gemspec")
        template 'templates/code_generators/model.rb', File.join(Origen.root, 'app', 'models', *@namespaces, "#{@name}.rb")
        template 'templates/code_generators/controller.rb', File.join(Origen.root, 'app', 'controllers', *@namespaces, "#{@name}_controller.rb")
      end
    end
  end
end
