module Origen
  module CodeGenerators
    class Model < Origen::CodeGenerators::Base
      def self.banner
        'origen new model NAME'
      end

      desc <<-END
This generator creates a model and optionally a controller for it within your application's
app/lib directory.

The NAME of the model should be given, in lower case, optionally indicating the presence
of any namespacing you want it to be created under.

If the model is intended to represent a top-level DUT or a primary sub-block/IP (e.g. RAM,
ATD, PLL, Flash, etc) then use `origen new dut` or `origen new block` instead.

If the model is intended to represent a sub-component of an existing block then the
block generator should be used to create a nested sub-block - see the comments within
sub_blocks.rb of one of the existing block models for an example.

Otherwise, models in the app/lib directory as produced by this generator are good for when
the model is representing some abstract concept which may not map directly to hardware, or
hen you need to model a minor sub-component which needs to be shared by multuple higher level
blocks.

Examples:
  origen new model sequencer       # Creates app/lib/my_application/sequencer.rb
  origen new model bist/sequencer  # Creates app/lib/my_application/bist/sequencer.rb
END

      def validate_args
        if args.size > 1 || args.size == 0
          msg = args.size > 1 ? 'Only one' : 'One'
          msg << " argument is expected by the model generator, e.g. 'origen new model sequencer', 'origen new model bist/sequencer'"
          puts msg
          exit 1
        end

        validate_resource_name(args.first)
      end

      def create_model_file
        @resource_path = args.first
        klass = resource_path_to_class(args.first)
        @namespaces = klass.split('::').map(&:underscore)
        @name = @namespaces.pop
        @namespaces = add_type_to_namespaces(@namespaces)
        @root_class = true
        file = class_name_to_lib_file(klass)
        template 'templates/code_generators/model.rb', file
        if yes? 'Does this model need a controller? (n):'
          file = file.to_s.sub(/\.rb/, '_controller.rb')
          template 'templates/code_generators/controller.rb', file
        end
        add_acronyms
      end
    end
  end
end
