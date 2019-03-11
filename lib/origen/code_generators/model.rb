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
ATD, PLL, Flash, etc) then use `origen new dut` or `origen new sub_block` instead.

If the model is intended to represent a sub-component of an existing sub-block then the
sub_block generator should be used to create a nested model - see the comments within
sub_blocks.rb of the existing sub-block model for an example.

Otherwise, models in the app/lib directory as produced by this generator and good for when
your model is representing some abstract concept which may not map directly to hardware, or
if you need to model a minor sub-component which needs to be shared by multuple higher level
models.

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
