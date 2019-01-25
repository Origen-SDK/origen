module Origen
  module CodeGenerators
    # Base generator for DUT and sub-block parts
    module PartCommon
      def validate_args_common(arg = nil)
        validate_resource_name(arg || args.first)
      end

      def extract_model_name
        @final_namespaces = args.first.downcase.split('/')

        @final_name = @final_namespaces.pop
        @final_name.gsub!(/\.rb/, '')

        @final_namespaces.unshift('dut') if @top_level
        @final_namespaces.unshift(underscored_app_namespace)

        @model_path = @final_namespaces.dup
        @namespaces = [[:module, @model_path.shift]]
      end

      def create_files
        # @summary = ask 'Describe your plugin in a few words:'
        @part = true
        @root_class = true

        # Nested sub-blocks do not support inheritance
        unless @nested
          dir = File.join(Origen.root, 'app', 'parts')
          @fullname = Origen.app.namespace.to_s

          @model_path.each do |path|
            dir = File.join(dir, path)
            @name = path
            @fullname += "::#{camelcase(@name)}"
            @resource_path = resource_path(dir)

            if @generate_model
              f = File.join(dir, 'model.rb')
              template 'templates/code_generators/model.rb', f unless File.exist?(f)
              f = File.join(dir, 'controller.rb')
              template 'templates/code_generators/controller.rb', f unless File.exist?(f)
            end
            if @generate_pins
              f = File.join(dir, 'pins.rb')
              template 'templates/code_generators/pins.rb', f unless File.exist?(f)
            end
            if @generate_timesets
              f = File.join(dir, 'timesets.rb')
              template 'templates/code_generators/timesets.rb', f unless File.exist?(f)
            end
            if @generate_parameters
              f = File.join(dir, 'parameters.rb')
              template 'templates/code_generators/parameters.rb', f unless File.exist?(f)
            end
            f = File.join(dir, 'registers.rb')
            template 'templates/code_generators/registers.rb', f unless File.exist?(f)
            f = File.join(dir, 'sub_blocks.rb')
            template 'templates/code_generators/sub_blocks.rb', f unless File.exist?(f)
            f = File.join(dir, 'attributes.rb')
            template 'templates/code_generators/attributes.rb', f unless File.exist?(f)
            dir = File.join(dir, 'derivatives')
            @namespaces << [:class, path]
            @root_class = false

            @parent_class = @namespaces.map { |type, name| camelcase(name) }.join('::')
          end

          @parent_class ||= @namespaces.map { |type, name| camelcase(name) }.join('::')
        end

        @name = @final_name
        @fullname += "::#{camelcase(@name)}"
        dir = @dir || File.join(dir, @name)
        @resource_path = resource_path(dir)

        if @generate_model
          template 'templates/code_generators/model.rb', File.join(dir, 'model.rb')
          template 'templates/code_generators/controller.rb', File.join(dir, 'controller.rb')
        end
        if @generate_pins
          template 'templates/code_generators/pins.rb', File.join(dir, 'pins.rb')
        end
        if @generate_timesets
          template 'templates/code_generators/timesets.rb', File.join(dir, 'timesets.rb')
        end
        if @generate_parameters
          template 'templates/code_generators/parameters.rb', File.join(dir, 'parameters.rb')
        end
        template 'templates/code_generators/registers.rb', File.join(dir, 'registers.rb')
        template 'templates/code_generators/sub_blocks.rb', File.join(dir, 'sub_blocks.rb')
        template 'templates/code_generators/attributes.rb', File.join(dir, 'attributes.rb')
      end

      def class_name
        (@final_namespaces + Array(@name)).map { |n| camelcase(n) }.join('::')
      end
    end
  end
end
