module Origen
  module CodeGenerators
    class Klass < Origen::CodeGenerators::Base
      def self.banner
        'origen new class NAME'
      end

      desc <<-END
This generator creates a plain old Ruby class within your application's lib directory.

The NAME of the class should be given, in lower case, optionally indicating the presence
of any namespacing you want it to be created under.

Examples:
  origen new class counter          # Creates app/lib/my_application/counter.rb
  origen new class helpers/counter  # Creates app/lib/my_application/helpers/counter.rb
END

      def validate_args
        validate_resource_name(args.first)

        if args.size > 1 || args.size == 0
          msg = "Only one argument is expected by the class generator, e.g. 'origen new class counter', 'origen new class helpers/counter'"
          Origen.log.error(msg)
          exit 1
        end
      end

      def create_class_file
        @resource_path = args.first
        klass = resource_path_to_class(args.first)
        @namespaces = klass.split('::').map(&:underscore)
        @name = @namespaces.pop
        @namespaces = add_type_to_namespaces(@namespaces)
        @root_class = true
        file = class_name_to_lib_file(klass)
        template 'templates/code_generators/class.rb', file
      end
    end
  end
end
