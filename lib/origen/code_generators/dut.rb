module Origen
  module CodeGenerators
    class Dut < Origen::CodeGenerators::Base
      def self.banner
        'origen new dut NAME [options]'
      end

      desc <<-END
This generator creates a top-level (DUT) model and associated resources for it, e.g. a controller,
target, timeset, pins, etc.

The name of the model should be given, in lower case, optionally prefixed by a sub-directory if you
want to create it in a sub-directory of app/duts/.

Examples:
  origen new dut falcon         # Creates app/duts/models/falcon.rb
  origen new dut dsps/falcon    # Creates app/duts/models/dsps/falcon.rb
END

      def extract_model_name
        if args.size > 1 || args.size == 0
          msg = args.size > 1 ? 'Only one' : 'One '
          msg << "argument is expected by the DUT generator, e.g. 'origen new dut my_soc', 'origen new dut my_family/my_soc"
          Origen.log.error(msg)
          exit 1
        end

        unless_lower_cased_underscored(ARGV.first) do
          Origen.log.error "The NAME argument must be all lower-cased and underscored - #{ARGV.first}"
          exit 1
        end

        @namespaces = ARGV.first.downcase.split('/')

        @name = @namespaces.pop
        @name.gsub!(/\.rb/, '')

        @namespaces.unshift(Origen.app.name.to_s) unless @namespaces.first == Origen.app.name.to_s

        @model_path = @namespaces.dup
        @model_path.shift
        @model_path
      end

      def create_files
        # @summary = ask 'Describe your plugin in a few words:'
        @top_level = true
        @dut_generator = true
        template 'templates/code_generators/model.rb', File.join(Origen.root, 'app', 'duts', 'models', *@model_path, "#{@name}.rb")
        template 'templates/code_generators/controller.rb', File.join(Origen.root, 'app', 'duts', 'controllers', *@model_path, "#{@name}_controller.rb")
        template 'templates/code_generators/pins.rb', File.join(Origen.root, 'app', 'pins', "#{@name}.rb")
        template 'templates/code_generators/timesets.rb', File.join(Origen.root, 'app', 'timesets', "#{@name}.rb")
        template 'templates/code_generators/parameters.rb', File.join(Origen.root, 'app', 'parameters', "#{@name}.rb")
        # add_autoload @name, namespaces: @namespaces
      end

      def create_target
        contents = ''
        contents << @namespaces.map { |n| n.to_s.camelcase }.join('::')
        contents << "::#{@name.to_s.camelcase}.new\n"

        create_file "#{Origen.root}/target/#{@name}.rb", contents
      end

      def completed
        puts
        puts 'New DUT model and target created, run the following command to select it in your workspace:'
        puts "  origen t #{@name}"
      end
    end
  end
end
