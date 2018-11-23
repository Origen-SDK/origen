module Origen
  module CodeGenerators
    class SubBlock < Origen::CodeGenerators::Base
      include PartCommon

      # class_option :duts, type: :boolean, desc: 'Instantiate the new sub-block in all DUT models', default: true
      # class_option :instance, desc: 'The main NAME argument will be the name given to the model and the instantiated sub-block, optionally provide a different name for the instance'

      def self.banner
        'origen new sub_block TYPE/DERIVATIVE'
      end

      desc <<-END
This generator creates a primary sub-block part (e.g. RAM, ATD, Flash, DAC, etc.) and all of the associated
resources for it, e.g. a model, controller, timesets, parameters, etc.

The TYPE and DERIVATIVE names should be given in lower case (e.g. flash/flash2kb, atd/atd16), optionally with
additional parent sub-block names after the initial type.

All parent sub-blocks will be created if they don't exist, but they will not be modified if they do.

Examples:
  origen new sub_block atd/atd8bit          # Creates app/parts/atd/derivatives/atd8bit/...
  origen new sub_block atd/atd16bit         # Creates app/parts/atd/derivatives/atd16bit/...
  origen new sub_block nvm/flash/flash2kb   # Creates app/parts/nvm/derivatives/flash/derivatives/flash2kb/...
END

      def validate_args
        validate_args_common

        if args.size > 1 || args.size == 0
          msg = args.size > 1 ? 'Only one' : 'One '
          msg << "argument is expected by the sub-block generator, e.g. 'origen new atd/atd16bit'"
          Origen.log.error(msg)
          exit 1
        end
        if args.first.split('/').size == 1
          msg = "You must supply a leading type to the name of the sub-block, e.g. 'origen new atd/atd16bit'"
          Origen.log.error(msg)
          exit 1
        end
      end

      def setup
        @generate_model = true
        @generate_pins = true
        extract_model_name
        create_files
      end

      def instantiate_sub_block
        @line = "sub_block :#{@final_namespaces[1]}, class_name: '#{class_name}'#, base_address: 0x4000_0000"

        unless duts.empty?
          puts
          @dut_index = [nil]
          duts.each do |name, children|
            print_dut(name, 1, children, 0)
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
                sub_blocks = class_name_to_part_dir(target).join('sub_blocks.rb')
                unless sub_blocks.exist?
                  orig = @fullname
                  @fullname = target
                  template 'templates/code_generators/sub_blocks.rb', sub_blocks
                  @fullname = orig
                end
                @sub_block_instantiated = true
                append_to_file sub_blocks, @line
              end
            end
          end
        end
      end

      def completed
        puts
        if @sub_block_instantiated
          puts 'New sub-block created and instantiated within your DUT(s) as:'.green + "  dut.#{@final_namespaces[1]}"
        else
          puts 'New sub-block created, you can instantiate it within your models like this:'.green
          puts
          puts "  #{@line}"
        end
        puts
      end

      private

      def print_dut(name, index, children, offset)
        @dut_index << name
        puts "#{index}".ljust(2) + ': ' + ('  ' * offset) + name
        index += 1
        children.each do |name, children|
          print_dut(name, index, children, offset + 1)
        end
      end

      # Returns a look up table for all dut models defined in this application (only those defined
      # as parts, as they all should be now).
      # This is arranged by hierarchy.
      def duts
        @duts ||= begin
          duts = {}
          dut_dir = Pathname.new(File.join(Origen.root, 'app', 'parts', 'dut'))
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
              name = "#{name}::#{item.basename.to_s.camelcase}"
              duts[name] = {}
              add_derivatives(duts[name], name, item)
            end
          end
        end
      end
    end
  end
end
