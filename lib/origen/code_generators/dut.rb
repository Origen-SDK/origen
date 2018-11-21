module Origen
  module CodeGenerators
    class Dut < Origen::CodeGenerators::Base
      def self.banner
        'origen new dut NAME [options]'
      end

      desc <<-END
This generator creates a top-level (DUT) part and all the associated resources for it, e.g. a model,
controller, target, timeset, pins, etc.

The name of the DUT should be given, in lower case, optionally prefixed by a sub-directory if you
want to create it in a sub-directory of app/duts/.

Examples:
  origen new dut falcon         # Creates app/parts/dut/derivatives/falcon/
  origen new dut dsps/falcon    # Creates app/parts/dut/derivatives/dsps/derivatives/falcon/
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

        @final_namespaces = ARGV.first.downcase.split('/')

        @final_name = @final_namespaces.pop
        @final_name.gsub!(/\.rb/, '')

        @final_namespaces.unshift('dut')
        @final_namespaces.unshift(Origen.app.name.to_s)

        @model_path = @final_namespaces.dup
        @namespaces = [[:module, @model_path.shift]]
      end

      def create_files
        # @summary = ask 'Describe your plugin in a few words:'
        @top_level = true
        @root_class = true
        @dut_generator = true
        @model_class = Origen.app.namespace
        @parent_model_class = nil

        dir = File.join(Origen.root, 'app', 'parts')

        @model_path.each do |path|
          dir = File.join(dir, path)
          @name = path
          f = File.join(dir, 'model.rb')
          template 'templates/code_generators/model.rb', f unless File.exist?(f)
          f = File.join(dir, 'controller.rb')
          template 'templates/code_generators/controller.rb', f unless File.exist?(f)
          f = File.join(dir, 'pins.rb')
          template 'templates/code_generators/pins.rb', f unless File.exist?(f)
          f = File.join(dir, 'timesets.rb')
          template 'templates/code_generators/timesets.rb', f unless File.exist?(f)
          f = File.join(dir, 'parameters.rb')
          template 'templates/code_generators/parameters.rb', f unless File.exist?(f)
          f = File.join(dir, 'registers.rb')
          template 'templates/code_generators/registers.rb', f unless File.exist?(f)
          f = File.join(dir, 'sub_blocks.rb')
          template 'templates/code_generators/sub_blocks.rb', f unless File.exist?(f)
          dir = File.join(dir, 'derivatives')
          @namespaces << [:class, path]
          @root_class = false
        end

        @parent_class = @namespaces.map { |type, name| name.camelcase }.join('::')
        @name = @final_name
        dir = File.join(dir, @name)

        template 'templates/code_generators/model.rb', File.join(dir, 'model.rb')
        template 'templates/code_generators/controller.rb', File.join(dir, 'controller.rb')
        template 'templates/code_generators/pins.rb', File.join(dir, 'pins.rb')
        template 'templates/code_generators/timesets.rb', File.join(dir, 'timesets.rb')
        template 'templates/code_generators/parameters.rb', File.join(dir, 'parameters.rb')
        template 'templates/code_generators/registers.rb', File.join(dir, 'registers.rb')
        template 'templates/code_generators/sub_blocks.rb', File.join(dir, 'sub_blocks.rb')
        # add_autoload @name, namespaces: @namespaces
      end

      def create_target
        contents = ''
        contents << @final_namespaces.map { |n| n.to_s.camelcase }.join('::')
        contents << "::#{@name.to_s.camelcase}.new\n"

        create_file "#{Origen.root}/target/#{@name}.rb", contents
      end

      def completed
        puts
        puts 'New DUT part created, run the following command to select it in your workspace:'
        puts "  origen t #{@name}"
      end
    end
  end
end
