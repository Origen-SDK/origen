module RGen
  module Tester
    class J750
      class Parser
        # Extracts embedded test and flow descriptions (comments) from test
        # program source files
        class Descriptions
          attr_accessor :source_directories, :template_directories, :parser

          SCRATCH_DIR = "#{RGen.root}/.j750_scratch"

          # All descriptions are stored in this lookup table
          def lookup
            return @lookup if @lookup
            # Use the one from the interface if present, program generation will
            # automatically push descriptions in here
            if RGen.interface_present?
              @lookup = RGen.interface.descriptions
            else
              @lookup = RGen::Tester::Parser::DescriptionLookup.new
            end
          end

          def initialize(options = {})
            @parser = options[:parser]
            FileUtils.rm_rf(SCRATCH_DIR) if File.exist?(SCRATCH_DIR)
            parse_program
            true
          end

          # Returns the description for the given flow
          def flow_summary(options = {})
            lookup.for_flow(options[:file])
          end

          # Returns the description of the given test from the test
          # instance sheet declaration
          def test_instance(options = {})
            lookup.for_test_definition(options[:name])
          end

          # Returns the description of the given test from the test
          # flow
          def flow_line(options = {})
            lookup.for_test_usage(options[:name], options[:flow])
          end

          def parse_program
            RGen.file_handler.preserve_state do
              generate_program_files
              # Comments must be extracted manually for any compiled files, for
              # generated files the comments will already be in the lookup
              extract_flow_summaries
              extract_test_instance_descriptions
              extract_flow_line_descriptions
            end
          end

          def source_directories
            [@source_directories, RGen.config.test_program_source_directory].compact.flatten
          end

          def template_directories
            [@template_directories, RGen.config.test_program_template_directory].compact.flatten
          end

          def extract_flow_summaries
            RGen.file_handler.resolve_files(compiled_dir) do |file|
              if flow_file?(file)
                lookup.add_for_flow(file, parse_flow_summary(file))
              end
            end
          end

          # Parses a compiled template for marked up comments
          def extract_test_instance_descriptions
            RGen.file_handler.resolve_files(compiled_dir) do |file|
              if instance_file?(file)
                comments = []
                File.readlines(file).each do |line|
                  if line =~ /^<comment>(.*)/
                    comments << Regexp.last_match[1].gsub("\r", '')
                  else
                    fields = line.split("\t")
                    unless ['Test Instances', '', 'Test Name'].include? fields[1]
                      lookup.add_for_test_definition(fields[1], comments)
                    end
                    comments = []
                  end
                end
              end
            end
          end

          def extract_flow_line_descriptions
            RGen.file_handler.resolve_files(compiled_dir) do |file|
              if flow_file?(file)
                f = file.basename('.txt').to_s
                comments = []
                header_line = true
                File.readlines(file).each do |line|
                  if header_line
                    header_line = false if line =~ /^\s*Label/
                  else
                    if line =~ /^<comment>(.*)/
                      comments << Regexp.last_match[1].gsub("\r", '')
                    else
                      t = FlowLine.extract_test(line)
                      if t
                        lookup.add_for_test_usage(t, file, comments)
                      end
                      comments = []
                    end
                  end
                end
              end
            end
          end

          def generate_program_files
            a = generate_program
            b = compile_program
            unless a || b
              fail 'No source or template files declared from which to parse descriptions!'
            end
          end

          # Parses the given flow file for summary text and returns it, summary
          # text must be the very first thing in the file.
          # Returns an array of strings each representing a line of text.
          def parse_flow_summary(file)
            desc = []
            File.readlines(file).each do |line|
              if line =~ /%?\s*<comment>(.*)/
                desc << Regexp.last_match[1].gsub("\r", '')
              else
                break
              end
            end
            desc
          end

          # Generate a scratch version of the program for parsing
          def generate_program
            if source_directories.size > 0
              unless @program_generated
                RGen.log.info ''
                RGen.log.info 'Extracting embedded comments:'
                RGen.log.info ''
                copy_source_files_to_scratch
                markup_source_file_comments
                # Compile the flow file, with Ruby comments now preserved and marked up
                desc = RGen.app.runner.generate(program: true, patterns: ungenerated_dir, output: generated_dir,
                                                check_for_changes: false, collect_stats: false, quiet: true,
                                                collect_descriptions: true)
                RGen.log.info ''
              end
              @program_generated = true
            else
              false
            end
          end

          # Compile a scratch version of the program for parsing
          def compile_program
            if template_directories.size > 0
              unless @program_compiled
                RGen.log.info ''
                RGen.log.info 'Extracting embedded comments:'
                RGen.log.info ''
                copy_templates_to_scratch
                markup_template_comments
                # Compile the flow file, with Ruby comments now preserved and marked up
                RGen.app.runner.generate(compile: true, patterns: uncompiled_dir, output: compiled_dir,
                                         check_for_changes: false, collect_stats: false, quiet: true)
                RGen.log.info ''
              end
              @program_compiled = true
            else
              false
            end
          end

          # Copy all flow and instance template files to the scratch dir
          def copy_templates_to_scratch
            uncompiled_dir(true)
            template_directories.each do |dir|
              RGen.file_handler.resolve_files(dir) do |file|
                subdir = file.relative_path_from(Pathname.new(dir)).dirname.to_s
                cpydir = "#{uncompiled_dir}/#{subdir}"
                FileUtils.mkdir_p(cpydir) unless File.exist?(cpydir)
                FileUtils.copy(file, cpydir) if flow_or_instance_file?(file)
              end
            end
            `chmod -R 777 #{uncompiled_dir}/*` unless Dir["#{uncompiled_dir}/*"].empty?
          end

          # Copy all flow and instance source files to the scratch dir
          def copy_source_files_to_scratch
            source_directories.each do |dir|
              RGen.file_handler.resolve_files(dir) do |file|
                subdir = file.relative_path_from(Pathname.new(dir)).dirname.to_s
                cpydir = "#{ungenerated_dir}/#{subdir}"
                FileUtils.mkdir_p(cpydir) unless File.exist?(cpydir)
                FileUtils.copy(file, cpydir)
              end
            end
          end

          def uncompiled_dir(force_make = false)
            @uncompiled_dir ||= "#{SCRATCH_DIR}/uncompiled"
            if force_make
              FileUtils.rm_rf(@uncompiled_dir) if File.exist?(@uncompiled_dir)
              @uncompiled_dir_created = false
            end
            unless @uncompiled_dir_created
              FileUtils.mkdir_p(@uncompiled_dir) unless File.exist?(@uncompiled_dir)
              @uncompiled_dir_created = true
            end
            @uncompiled_dir
          end

          def ungenerated_dir
            @ungenerated_dir ||= "#{SCRATCH_DIR}/ungenerated"
            unless @ungenerated_dir_created
              FileUtils.mkdir_p(@ungenerated_dir) unless File.exist?(@ungenerated_dir)
              @ungenerated_dir_created = true
            end
            @ungenerated_dir
          end

          def compiled_dir
            @compiled_dir ||= "#{SCRATCH_DIR}/compiled"
            unless @compiled_dir_created
              FileUtils.mkdir_p(@compiled_dir) unless File.exist?(@compiled_dir)
              @compiled_dir_created = true
            end
            @compiled_dir
          end

          def generated_dir
            @generated_dir ||= "#{SCRATCH_DIR}/generated"
            unless @generated_dir_created
              FileUtils.mkdir_p(@generated_dir) unless File.exist?(@generated_dir)
              @generated_dir_created = true
            end
            @generated_dir
          end

          # Returns true if the given file looks like a J750 flow file, works for
          # templates to
          def flow_or_instance_file?(file, options = {})
            options = { flow:     true,
                        instance: true
            }.merge(options)
            if options[:flow] && options[:instance]
              match = 'Flow|Instances'
            elsif options[:flow]
              match = 'Flow'
            else
              match = 'Instances'
            end
            # Not sure the best way to determine the file type of a partial, just
            # return true for now to play it safe
            return true if file.basename.to_s =~ /^_/
            File.readlines(file).each do |line|
              begin
                unless line =~ /^%/ || line =~ /^\s*<comment>/
                  return !!(line =~ /#{match}/)
                end
              rescue Exception => e
                if e.is_a?(ArgumentError) && e.message =~ /invalid byte sequence/
                  return false
                else
                  puts e.message
                  puts e.backtrace
                  exit 1
                end
              end
            end
          end

          def flow_file?(file)
            flow_or_instance_file?(file, instance: false)
          end

          def instance_file?(file)
            flow_or_instance_file?(file, flow: false)
          end

          # Substitute Ruby line comments so they are preserved by compilation
          def markup_template_comments
            RGen.file_handler.resolve_files(uncompiled_dir) do |file|
              lines = File.readlines(file)
              File.open(file, 'w') do |f|
                lines.each do |line|
                  if line =~ /^%\s*#\s?(.*)/ # Remove single leading whitespace from comment if it exists
                    comment = Regexp.last_match[1]
                    # If comment starts with a '#-' it should be removed by compilation
                    if line =~ /^%\s*#-.*/
                      f.write line
                    # Otherwise preserve it
                    else
                      f.write "<comment>#{comment}\n"
                    end
                  else
                    f.write line
                  end
                end
              end
            end
          end

          # Substitute Ruby line comments so they are preserved by generation
          def markup_source_file_comments
            RGen.file_handler.resolve_files(ungenerated_dir) do |file|
              lines = File.readlines(file)
              File.open(file, 'w') do |f|
                lines.each do |line|
                  if line =~ /^\s*#\s?(.*)/ # Remove single leading whitespace from comment if it exists
                    comment = Regexp.last_match[1]
                    # If comment starts with a '#-' it should be removed by generation
                    if line =~ /^\s*#-.*/
                      f.write line
                    # Otherwise preserve it
                    else
                      f.write "RGen.interface.comment '#{comment}'\n"
                    end
                  else
                    f.write line
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
