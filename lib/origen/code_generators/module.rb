module Origen
  module CodeGenerators
    class Mod < Origen::CodeGenerators::Base
      def self.banner
        'origen new module NAME [CLASS]'
      end

      desc <<-END
This generator creates a plain old Ruby module within your application's lib directory,
or if a CLASS argument is given, it will create it a child of that class in either the
lib or models directory as appropriate.

Where a CLASS argument is given, the new module will be automatically included in the
class.

The NAME of the module should be given, in lower case, optionally indicating the presence
of any namespacing you want it to be created under.

The CLASS argument should be a path to the Ruby file that defines the class.

Examples:
  origen new module helpers          # Creates app/lib/my_application/helpers.rb
  origen new module helpers/math     # Creates app/lib/my_application/helpers/math.rb

  # Creates app/lib/models/dut/derivatives/falcon/model/helpers.rb
  origen new module models/dut/derivatives/falcon/model.rb helpers
END

      def validate_args
        if args.size > 2 || args.size == 0
          msg = args.size == 0 ? 'At least one argument is' : 'No more than two arguments are'
          msg << " expected by the module generator, e.g. 'origen new module helpers', 'origen new module helpers app/lib/my_app/my_class.rb'"
          puts msg
          exit 1
        end

        if args.size == 2
          @class_file = args.first
          unless File.exist?(@class_file)
            puts "This class file does not exist: #{@class_file}"
            exit 1
          end
        end

        @resource_path = validate_resource_path(args.last)
      end

      def create_module_file
        if @class_file
          @namespaces = resource_path_to_class(@class_file).split('::').map(&:underscore)
          paths = resource_path_to_class(@resource_path).split('::').map(&:underscore)
          @name = paths.pop
          paths.shift  # Lose the app namespace
          @namespaces += paths
          file = File.join(@class_file.sub('.rb', ''), "#{@name}.rb")
          @module_name = (@namespaces + [@name]).map { |n| camelcase(n) }.join('::')
        else
          @module_name = resource_path_to_class(@resource_path)
          @namespaces = @module_name.split('::').map(&:underscore)
          @name = @namespaces.pop
          file = class_name_to_lib_file(@module_name)
        end
        @namespaces = add_type_to_namespaces(@namespaces)
        template 'templates/code_generators/module.rb', file
      end

      def include_module
        if @class_file
          klass = resource_path_to_class(@class_file)

          # Does file have a nested namespace structure
          snippet = File.foreach(@class_file).first(50)
          if snippet.any? { |line| line =~ /\s*class #{klass.split('::').last}/ }
            indent = '  ' * klass.split('::').size
            lines = []
            lines << indent + "include #{@module_name}"
            lines << ''
            inject_into_class @class_file, klass.split('::').last, lines.join("\n") + "\n"

          # Else assume it is the compact style (class MyApp::DUT::Falcon)
          else
            lines = []
            lines << "  include #{@module_name}"
            lines << ''
            inject_into_class @class_file, klass, lines.join("\n") + "\n"
          end
        end
        add_acronyms
      end
    end
  end
end
