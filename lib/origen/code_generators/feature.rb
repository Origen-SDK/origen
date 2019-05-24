module Origen
  module CodeGenerators
    class Feature < Origen::CodeGenerators::Base
      include BlockCommon

      def self.banner
        'origen new feature NAME'
      end

      desc <<-END
This generator creates a new feature block, which is similar to a regular block but with no model and controller.
Such features can then be loaded (re-used) by multiple blocks within your application code.

The name of the feature should be given in lower case, optionally prefixed by parent feature name(s) separated
by a forward slash.

Any parent features will be created if they don't exist, but they will not be modified if they do.

Examples:
  origen new feature my_feature              # Creates app/blocks/my_feature/...
  origen new feature features/my_feature     # Creates app/blocks/features/my_feature/...

The above can then be loaded to models in your application code via:

  my_model.load_block('my_feature')
  my_model.load_block('features/my_feature')
END

      def validate_args
        if args.size > 1 || args.size == 0
          msg = args.size > 1 ? 'Only one' : 'One'
          msg << " argument is expected by the feature generator, e.g. 'origen new feature my_feature', 'origen new feature features/my_feature"
          puts msg
          exit 1
        end
        validate_args_common
      end

      def setup
        @generate_model = false
        @generate_pins = true
        @generate_timesets = true
        @generate_parameters = true
        extract_model_name
        create_files
        add_acronyms
      end
    end
  end
end
