module Origen
  module CodeGenerators
    class SubBlock < Origen::CodeGenerators::Base
      class_option :duts, type: :boolean, desc: 'Instantiate the new sub-block in all DUT models', default: true
      class_option :instance, desc: 'The main NAME argument will be the name given to the model and the instantiated sub-block, optionally provide a different name for the instance'

      def self.banner
        'origen new sub_block NAME [paths to duts/sub_blocks] [options]'
      end

      desc <<-END
This generator creates a sub-block model and controller, and will optionally instantiate it
within a given DUT(s) or other sub-block(s).

The name of the model should be given, in lower case, optionally prefixed by a sub-directory if you
want to create it in a sub-directory of app/sub_blocks/.

Examples:
  origen new sub_block nvm                                                     # Creates app/sub_blocks/models/nvm.rb, and instantiates it in all DUT models
  origen new sub_block memories/nvm                                            # As above, but creates app/sub_blocks/models/memories/nvm.rb
  origen new sub_block nvm --no-duts                                           # Skips instantiating the new sub-block in the DUT models
  origen new sub_block nvm app/duts/models/falcon.rb                           # Only instantiates in the given DUT model
  origen new sub_block nvm app/sub_blocks/models/memories.rb                   # Instantiates in the given sub-block model
  origen new sub_block nvm app/duts/models/falcon.rb app/duts/models/eagle.rb  # Example of supplying multiple models to instantiate in
  origen new sub_block flash_2k --instance nvm                                 # Creates a model called Flash2k, but will instantiate it as dut.nvm
END

      def extract_model_name
        if args.size == 0
          msg = "At least one argument is required by the sub_block generator, e.g. 'origen new sub_block nvm', run with '-h' to see more examples"
          Origen.log.error(msg)
          exit 1
        end

        unless_lower_cased_underscored(ARGV.first) do
          Origen.log.error "The NAME argument must be all lower-cased and underscored - #{ARGV.first}"
          exit 1
        end

        @namespaces = ARGV.shift.downcase.split('/')

        ARGV.each do |f|
          unless File.exist?(f)
            Origen.log.error "The given file does not exist - #{f}"
            exit 1
          end
        end

        @name = @namespaces.pop
        @name.gsub!(/\.rb/, '')

        @namespaces.unshift(Origen.app.name.to_s) unless @namespaces.first == Origen.app.name.to_s

        @model_path = @namespaces.dup
        @model_path.shift
        @model_path
      end

      def create_files
        # @summary = ask 'Describe your plugin in a few words:'
        template 'templates/code_generators/model.rb', File.join(Origen.root, 'app', 'sub_blocks', 'models', *@model_path, "#{@name}.rb")
        template 'templates/code_generators/controller.rb', File.join(Origen.root, 'app', 'sub_blocks', 'controllers', *@model_path, "#{@name}_controller.rb")
      end

      def instantiate_sub_block
        if ARGV.size > 0
          ARGV.each { |f| instantiate_in(f) }
        elsif options[:duts]
          Dir.glob(Origen.root.join('app', 'duts', 'models', '**', '*.rb')).each do |f|
            # Verify that it is a top-level/DUT model
            instantiate_in(f) if File.read(f) =~ /^\s*include\s+Origen::TopLevel/
          end
        end
      end

      def completed
      end

      private

      def class_name
        (@namespaces + Array(@name)).map(&:camelcase).join('::')
      end

      def instantiate_in(file)
        if File.exist?(file)
          ensure_define_sub_blocks(file)
          sentinel = /^\s*def define_sub_blocks.*$/
          insert_into_file file, after: sentinel do
            "\n#{'  ' * internal_depth(file)}  sub_block :#{options[:instance] || @name}, class_name: '#{class_name}'#, base_address: 0x4000_0000"
          end
        else
          Origen.log.error("File does not exist, no sub-block definition added - #{file}")
        end
      end

      # Adds a define_sub_blocks method if not present
      def ensure_define_sub_blocks(file)
        unless_has_method(file, :define_sub_blocks) do
          indent = '  ' * internal_depth(file)
          klass = Pathname.new(file).basename('.rb').to_s.camelcase
          inject_into_class file, klass do
            <<-END
#{indent}# Define this model's sub_blocks within this method, this will be called
#{indent}# automatically whenever this model is instantiated
#{indent}def define_sub_blocks(options = {})
#{indent}end

END
          end
        end
      end
    end
  end
end
