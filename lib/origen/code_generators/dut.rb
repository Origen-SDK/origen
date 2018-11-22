module Origen
  module CodeGenerators
    class Dut < Origen::CodeGenerators::Base
      include PartCommon

      def self.banner
        'origen new dut NAME [options]'
      end

      desc <<-END
This generator creates a top-level (DUT) part and all of the associated resources for it, e.g. a model,
controller, target, timesets, pins, etc.

The name of the DUT should be given in lower case, optionally prefixed by parent DUT name(s) separated
by a forward slash.

Any parent DUT(s) will be created if they don't exist, but they will not be modified if they do.

Examples:
  origen new dut falcon         # Creates app/parts/dut/derivatives/falcon/...
  origen new dut dsp/falcon     # Creates app/parts/dut/derivatives/dsp/derivatives/falcon/...
END

      def validate_args
        validate_args_common

        if args.size > 1 || args.size == 0
          msg = args.size > 1 ? 'Only one' : 'One '
          msg << "argument is expected by the DUT generator, e.g. 'origen new dut my_soc', 'origen new dut my_family/my_soc"
          Origen.log.error(msg)
          exit 1
        end
      end

      def setup
        @generate_model = true
        @generate_pins = true
        @top_level = true
        extract_model_name
        create_files
      end

      def create_target
        contents = ''
        contents << @final_namespaces.map { |n| n.to_s.camelcase }.join('::')
        contents << "::#{@name.to_s.camelcase}.new\n"

        create_file "#{Origen.root}/target/#{@name}.rb", contents
      end

      def completed
        puts
        puts 'New DUT part created, run the following command to select it in your workspace:'.green
        puts
        puts "  origen t #{@name}"
        puts
      end
    end
  end
end
