require 'active_support/concern'
require 'erb'
require 'yaml'

module Origen
  module Tester
    module Generator
      autoload :Placeholder,   'origen/tester/generator/placeholder'
      autoload :IdentityMap,   'origen/tester/generator/identity_map'
      autoload :FlowControlAPI, 'origen/tester/generator/flow_control_api'

      extend ActiveSupport::Concern

      included do
        include Origen::Generator::Comparator
      end

      # The program source files are executed by eval to allow the tester to filter the
      # source contents before executing. For examples the doc tester replaces all comments
      # with a method call containing each comment so that they can be captured.
      def self.execute_source(file)
        if Origen.tester.doc? && Origen.interface_loaded? && Origen.interface.respond_to?(:filter_source)
          File.open(file) do |f|
            src = f.read
            src = Origen.interface.filter_source(src)
            # With source file wrapping here to ensure that any calls to Origen.app! within
            # the source code will evaluate to the correct app instance
            Origen.with_source_file(file) do
              eval(src, global_binding)
            end
          end
        else
          load file
        end
      end

      # When called on a generater no output files will be created from it
      def inhibit_output
        @inhibit_output = true
      end

      # Returns true if the output files from this generator will be inhibited
      def output_inhibited?
        @inhibit_output
      end

      # Expands and inserts all render statements that have been encountered
      def close(options = {})
        Origen.profile "closing #{filename}" do
          base_collection = collection
          base_collection.each_with_index do |item, i|
            if item.is_a? Placeholder
              if item.type == :render
                txt = ''
                Origen.file_handler.preserve_current_file do
                  Origen.file_handler.default_extension = file_extension
                  placeholder = compiler.render(item.file, item.options)
                  txt = compiler.insert(placeholder).chomp
                end
                base_collection[i] = txt
              else
                fail 'Unknown placeholder encountered!'
              end
            end
          end
          @collection = base_collection.flatten.compact
          on_close(options)
        end
      end

      def file_pipeline
        @@file_pipeline ||= []
      end

      # Returns the directory of the current source file being generated
      def current_dir
        if file_pipeline.empty?
          Origen.file_handler.base_directory
        else
          Pathname.new(file_pipeline.last).dirname
        end
      end

      # Redefine this in the parent which includes this module if you want anything to
      # occur after closing the generator (expanding all render/import statements) but
      # before writing to a file.
      def on_close(_options = {})
      end

      # Redefine this in the parent which includes this module if you want anything to
      # occur after all tests have been generated but before file writing starts.
      def finalize(_options = {})
      end

      def compiler
        Origen.generator.compiler
      end

      def filename=(name)
        @filename = name
      end

      def filename(options = {})
        options = {
          include_extension: true
        }.merge(options)
        name = (@filename || Origen.file_handler.current_file.basename('.rb')).to_s
        if Origen.config.program_prefix
          unless name =~ /^#{Origen.config.program_prefix}/i
            name = "#{Origen.config.program_prefix}_#{name}"
          end
        end
        f = Pathname.new(name).basename
        ext = f.extname.empty? ? file_extension : f.extname
        body = f.basename(".#{ext}").to_s
        body.gsub!('_resources', '')
        if defined? self.class::OUTPUT_POSTFIX
          # Unless the postfix is already in the name
          unless body =~ /#{self.class::OUTPUT_POSTFIX}$/i
            body = "#{body}_#{self.class::OUTPUT_POSTFIX}"
          end
        end
        ext = ".#{ext}" unless ext =~ /^\./
        if options[:include_extension]
          "#{body}#{ext}"
        else
          "#{body}"
        end
      end

      def dont_diff=(val)
        @dont_diff = val
      end

      # All generators must implement a collection method that returns an
      # array containing the generated items
      def collection
        @collection ||= []
      end

      def collection=(array)
        @collection = array
      end

      def file_extension
        if defined? self.class::OUTPUT_EXTENSION
          self.class::OUTPUT_EXTENSION
        elsif defined? self.class::TEMPLATE
          p = Pathname.new(self.class::TEMPLATE)
          ext = p.basename('.erb').extname
          ext.empty? ? 'txt' : ext
        else
          'txt'
        end
      end

      def write_to_file(options = {})
        unless output_inhibited?
          if defined? self.class::TEMPLATE || Origen.tester.is_a?(Origen::Tester::Doc)
            write_from_template(options)
          else
            fail "Don't know hot to write without a template!"
          end
          stats.completed_files += 1
        end
      end

      def write_from_template(options = {})
        options = {
          quiet:     false,
          skip_diff: false
        }.merge(options)
        unless output_inhibited?
          # If this is not the first time we have written to the current output file
          # then appen to it, otherwise clear it and start from scratch.
          # The use of a class variable to store the opened files means that it will be
          # shared by all generators in this run.
          @@opened_files ||= []
          if @@opened_files.include?(output_file) && !Origen.tester.is_a?(Origen::Tester::Doc)
            @append = true
            Origen.file_handler.preserve_state do
              File.open(output_file, 'a') do |out|
                content = compiler.insert(ERB.new(File.read(self.class::TEMPLATE), 0, Origen.config.erb_trim_mode).result(binding))
                out.puts content unless content.empty?
              end
            end
            Origen.log.info "Appending... #{output_file.basename}" unless options[:quiet]
          else
            @append = false
            Origen.file_handler.preserve_state do
              if Origen.tester.is_a?(Origen::Tester::Doc)
                if options[:return_model]
                  Origen::Tester::Doc.model.add_flow(filename(include_extension: false), to_yaml)
                else
                  Origen.file_handler.open_for_write(output_file) do |f|
                    f.puts YAML.dump(to_yaml(include_descriptions: false))
                  end
                end
              else
                File.open(output_file, 'w') do |out|
                  out.puts compiler.insert(ERB.new(File.read(self.class::TEMPLATE), 0, Origen.config.erb_trim_mode).result(binding))
                end
              end
            end
            @@opened_files << output_file
            Origen.log.info "Writing... #{output_file.basename}" unless options[:quiet]
          end
          if !@dont_diff && !options[:skip_diff] && !options[:quiet]
            check_for_changes(output_file, reference_file,
                              compile_job:  true,
                              comment_char: Origen.app.tester.program_comment_char)
          end
        end
      end

      def output_file
        Pathname.new("#{Origen.file_handler.output_directory}/#{filename}")
      end

      def reference_file
        Pathname.new("#{Origen.file_handler.reference_directory}/#{filename}")
      end

      def import(file, options = {})
        file = Pathname.new(file).absolute? ? file : "#{current_dir}/#{file}"
        file = Origen.file_handler.clean_path_to_sub_program(file)
        base_collection = collection
        @collection = []
        Origen.generator.option_pipeline << options
        file_pipeline << file
        Origen::Tester::Generator.execute_source(file)
        file_pipeline.pop
        base_collection << @collection
        @collection = base_collection.flatten
      end

      def render(file, options = {})
        if options.delete(:_inline)
          super Origen.file_handler.clean_path_to_sub_template(file), options
        else
          collection << Placeholder.new(:render, file, options)
        end
      end

      def stats
        Origen.app.stats
      end

      def to_be_written?
        true
      end

      def set_flow_description(desc)
        Origen.interface.descriptions.add_for_flow(output_file, desc)
      end

      def identity_map # :nodoc:
        Origen.interface.identity_map
      end

      module ClassMethods
        def new(*args, &block) # :nodoc:
          x = allocate
          x.send(:initialize, *args, &block)
          Origen.interface.sheet_generators << x
          x
        end
      end
    end
  end
end
