module Origen
  module CodeGenerators
    class Part < Origen::CodeGenerators::Base
      include PartCommon

      def self.banner
        'origen new part NAME'
      end

      desc <<-END
This generator creates a loadable part (timesets, parameters, registers, etc.) which is similar to a DUT or
a sub-block part, but with no model and controller.
The intended use case is that this generates parts representing features that you can then load to multiple
DUT or sub-block models within your application code.

The name of the part should be given in lower case, optionally prefixed by parent part name(s) separated
by a forward slash.

Any parent parts will be created if they don't exist, but they will not be modified if they do.

Examples:
  origen new part my_feature              # Creates app/parts/my_feature/...
  origen new part features/my_feature     # Creates app/parts/features/my_feature/...

The above can then be loaded to models in your application code via:

  my_model.load_part('my_feature')
  my_model.load_part('features/my_feature')
END

      def validate_args
        validate_args_common

        if args.size > 1 || args.size == 0
          msg = args.size > 1 ? 'Only one' : 'One '
          msg << "argument is expected by the part generator, e.g. 'origen new part my_feature', 'origen new part features/my_feature"
          Origen.log.error(msg)
          exit 1
        end
      end

      def setup
        @generate_model = false
        @generate_pins = true
        @generate_timesets = true
        @generate_parameters = true
        extract_model_name
        create_files
      end
    end
  end
end
