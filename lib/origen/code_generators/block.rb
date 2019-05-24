module Origen
  module CodeGenerators
    class Block < Origen::CodeGenerators::Base
      include BlockCommon

      # class_option :duts, type: :boolean, desc: 'Instantiate the new sub-block in all DUT models', default: true
      # class_option :instance, desc: 'The main NAME argument will be the name given to the model and the instantiated sub-block, optionally provide a different name for the instance'

      def self.banner
        'origen new block [TYPE/]DERIVATIVE [BLOCK]'
      end

      desc <<-END
This generator creates a block (e.g. to represent RAM, ATD, Flash, DAC, etc.) and all of the associated
resources for it, e.g. a model, controller, timesets, parameters, etc.

The TYPE and DERIVATIVE names should be given in lower case (e.g. flash/flash2kb, atd/atd16), optionally with
additional parent sub-block names after the initial type.

Alternatively, a reference to an existing BLOCK can be added, in which case a nested sub-block will be created
within that block, rather than a primary block.
Note that nested sub-blocks do not support derivatives or inheritance and should therefore only be used for
relatively simple entities which are tightly coupled to a parent block.

Any parent block(s) will be created if they don't exist, but they will not be modified if they do.

Examples:
  origen new block atd/atd8bit          # Creates app/blocks/atd/derivatives/atd8bit/...
  origen new block atd/atd16bit         # Creates app/blocks/atd/derivatives/atd16bit/...
  origen new block nvm/flash/flash2kb   # Creates app/blocks/nvm/derivatives/flash/derivatives/flash2kb/...

  # Example of creating a nested sub-block
  origen new block nvm/flash/flash2kb bist   # Creates app/blocks/nvm/derivatives/flash/derivatives/flash2kb/sub_blocks/bist/...
END

      def validate_args
        if args.size > 2 || args.size == 0
          msg = args.size == 0 ? 'At least one argument is' : 'No more than two arguments are'
          msg << " expected by the sub-block generator, e.g. 'origen new block atd/atd16bit', 'origen new block sampler app/blocks/atd/derivatives/atd16bit"
          puts msg
          exit 1
        end

        if args.size == 2
          validate_args_common(args.last)
        else
          validate_args_common
        end

        @nested = args.size == 2
        if !@nested && args.first.split('/').size == 1
          msg = "You must supply a leading type to the name of the sub-block, e.g. 'origen new block atd/atd16bit'"
          puts msg
          exit 1
        end
        if @nested && args.last.split('/').size != 1
          msg = "No leading type is allowed when generating a nested sub-block, e.g. 'origen new block sampler app/blocks/atd/derivatives/atd16bit"
          puts msg
          exit 1
        end
      end

      def setup
        @generate_model = true
        @generate_pins = false
        @generate_timesets = !@nested
        @generate_parameters = !@nested
        if @nested
          @final_name = args.last
          @fullname = resource_path_to_class(args.first)
          @dir = resource_path_to_blocks_dir(args.first).join('sub_blocks', @final_name)
          @namespaces = add_type_to_namespaces(@fullname.split('::').map(&:underscore))
        else
          extract_model_name
        end
        create_files
      end

      def instantiate_sub_block
        if @nested
          # First create the parent's sub_blocks.rb file if it doesn't exist
          f = "#{@dir.parent}.rb"
          unless File.exist?(f)
            @nested = false
            orig_fullname = @fullname
            orig_resouce_path = @resource_path
            @fullname = @fullname.split('::')
            @fullname.pop
            @fullname = @fullname.join('::')
            @resource_path = @resource_path.split('/')
            @resource_path.pop
            @resource_path = @resource_path.join('/')
            template 'templates/code_generators/sub_blocks.rb', f
            @fullname = orig_fullname
            @resource_path = orig_resouce_path
            @nested = true
          end

          line = "sub_block :#{@final_name}, class_name: '#{@fullname}'#, base_address: 0x4000_0000"
          append_to_file f, "\n#{line}"
        else
          @line = "sub_block :#{@final_namespaces[1]}, class_name: '#{class_name}'#, base_address: 0x4000_0000"

          unless duts.empty?
            puts
            @dut_index = [nil]
            index = 1
            duts.each do |name, children|
              index = print_dut(name, index, children, 0)
            end
            puts
            puts 'DO YOU WANT TO INSTANTIATE THIS SUB-BLOCK IN YOUR DUT MODELS?'
            puts
            puts 'If so enter the number(s) of the DUT(s) you wish to add it to from the list above, separating multiple entries with a space'
            puts '(note that adding it to a parent DUT in the hierarchy will already be adding it to all of its children).'
            puts
            response = ask 'Enter the DUT number(s), or just press return to skip:'

            done = []
            response.strip.split(/\s+/).each do |index|
              index = index.to_i
              target = @dut_index[index]
              if target
                # Don't add the sub-block to children if we've already added it to the parent, this will
                # cause an already defined sub-block error since it will be added by both instantiations
                unless done.any? { |c| target =~ /^#{c}::/ }
                  done << target
                  sub_blocks = class_name_to_blocks_dir(target).join('sub_blocks.rb')
                  unless sub_blocks.exist?
                    orig = @fullname
                    @fullname = target
                    template 'templates/code_generators/sub_blocks.rb', sub_blocks
                    @fullname = orig
                  end
                  @sub_block_instantiated = true
                  append_to_file sub_blocks, "\n#{@line}"
                end
              end
            end
          end
        end
      end

      def completed
        add_acronyms
        puts
        if @nested
          puts 'New sub-block created and instantiated.'.green
        else
          if @sub_block_instantiated
            puts 'New sub-block created and instantiated within your DUT(s) as:'.green + "  dut.#{@final_namespaces[1]}"
          else
            puts 'New sub-block created, you can instantiate it within your blocks like this:'.green
            puts
            puts "  #{@line}"
          end
        end
        puts
      end

      private

      def print_dut(name, index, children, offset)
        @dut_index << name
        puts "#{index}".ljust(2) + ': ' + ('  ' * offset) + name
        index += 1
        children.each do |name, children|
          index = print_dut(name, index, children, offset + 1)
        end
        index
      end

      # Returns a look up table for all dut blocks defined in this application (only those defined
      # as blocks, as they all should be now).
      # This is arranged by hierarchy.
      def duts
        @duts ||= begin
          duts = {}
          dut_dir = Pathname.new(File.join(Origen.root, 'app', 'blocks', 'dut'))
          if dut_dir.exist?
            name = "#{Origen.app.namespace}::DUT"
            duts[name] = {}
            add_derivatives(duts[name], name, dut_dir)
          end
          duts
        end
      end

      def add_derivatives(duts, name, dir)
        derivatives = dir.join('derivatives')
        if derivatives.exist?
          derivatives.children.each do |item|
            if item.directory?
              child_name = "#{name}::#{camelcase(item.basename)}"
              duts[child_name] = {}
              add_derivatives(duts[child_name], child_name, item)
            end
          end
        end
      end
    end
  end
end
