require 'open-uri'

module Origen
  module CodeGenerators
    # Common helpers available to all Origen code generators.
    # Some of these have been copied from Rails and don't make a lot of sense in an Origen context,
    # however they are being kept around for now as they serve as good examples of how to write
    # generator helpers.
    module Actions
      def initialize(*args) # :nodoc:
        if args.last.is_a?(Hash)
          @config = args.last.delete(:config) || {}
        end
        super
        @in_group = nil
      end

      def config
        @config
      end

      # Adds an autoload statement for the given resource name into +app/lib/my_app_name.rb+
      #
      # An array of namespaces can optionally be supplied in the arguments. The name and namespaces
      # should all be lower cased and underscored.
      #
      #   add_autoload "my_model", namespaces: ["my_namespace", "my_other_namespace"]
      def add_autoload(name, options = {})
        namespaces = Array(options[:namespaces])
        # Remove the app namespace if present, we will add the autoload inside the top-level module block
        namespaces.shift if namespaces.first == Origen.app.name.to_s
        top_level_file = File.join('app', 'lib', "#{Origen.app.name}.rb")

        if namespaces.empty?
          line = "  autoload :#{name.to_s.camelcase}, '#{Origen.app.name}/#{name}'\n"
          insert_into_file top_level_file, line, after: /module #{Origen.app.namespace}\n/
        else
          contents = File.read(top_level_file)
          regex = "module #{Origen.app.namespace}\s*(#.*)?\n"
          indent = ''
          namespaces.each do |namespace|
            indent += '  '
            new_regex = regex + "(\n|.)*^\s*module #{namespace.to_s.camelcase}\s*(#.*)?\n"
            unless contents =~ Regexp.new(new_regex)
              lines = "#{indent}module #{namespace.to_s.camelcase}\n"
              lines << "#{indent}end\n"
              insert_into_file top_level_file, lines, after: Regexp.new(regex), force: true
            end
            regex = new_regex
          end
          line = "#{indent}  autoload :#{name.to_s.camelcase}, '#{Origen.app.name}/#{namespaces.join('/')}/#{name}'\n"
          insert_into_file top_level_file, line, after: Regexp.new(regex)
        end
      end

      # Removes (comments out) the specified configuration setting from +config/application.rb+
      #
      #   comment_config :semantically_version
      def comment_config(name, options = {})
        # Set the message to be shown in logs
        log :comment, name

        file = File.join(Origen.root, 'config', 'application.rb')
        comment_lines(file, /^\s*config.#{name}\s*=.*\n/)
      end

      # Adds an entry into +config/application.rb+
      def add_config(name, value, options = {})
        # Set the message to be shown in logs
        message = name.to_s
        if value ||= options.delete(:value)
          message << " (#{value})"
        end
        log :insert, message

        file = File.join(Origen.root, 'config', 'application.rb')
        value = quote(value) if value.is_a?(String)
        value = ":#{value}" if value.is_a?(Symbol)
        insert_into_file file, "  config.#{name} = #{value}\n\n", after: /^\s*class.*\n/
      end

      # Adds an entry into +Gemfile+ for the supplied gem.
      #
      #   gem "rspec", group: :test
      #   gem "technoweenie-restful-authentication", lib: "restful-authentication", source: "http://gems.github.com/"
      #   gem "rails", "3.0", git: "git://github.com/rails/rails"
      def gem(name, version, options = {})
        # Set the message to be shown in logs. Uses the git repo if one is given,
        # otherwise use name (version).
        parts, message = [quote(name)], name
        if version ||= options.delete(:version)
          parts << quote(version)
          message << " (#{version})"
        end
        message = options[:git] if options[:git]

        log :gemfile, message

        options.each do |option, value|
          parts << "#{option}: #{quote(value)}"
        end

        in_root do
          str = "gem #{parts.join(', ')}"
          str = '  ' + str if @in_group
          str = "\n" + str
          append_file 'Gemfile', str, verbose: false
        end
      end

      # Wraps gem entries inside a group.
      #
      #   gem_group :development, :test do
      #     gem "rspec-rails"
      #   end
      def gem_group(*names, &block)
        name = names.map(&:inspect).join(', ')
        log :gemfile, "group #{name}"

        in_root do
          append_file 'Gemfile', "\ngroup #{name} do", force: true

          @in_group = true
          instance_eval(&block)
          @in_group = false

          append_file 'Gemfile', "\nend\n", force: true
        end
      end

      # Add the given source to +Gemfile+
      #
      #   add_source "http://gems.github.com/"
      def add_source(source, _options = {})
        log :source, source

        in_root do
          prepend_file 'Gemfile', "source #{quote(source)}\n", verbose: false
        end
      end

      # Adds a line inside the Application class for <tt>config/application.rb</tt>.
      #
      # If options <tt>:env</tt> is specified, the line is appended to the corresponding
      # file in <tt>config/environments</tt>.
      #
      #   environment do
      #     "config.autoload_paths += %W(#{config.root}/extras)"
      #   end
      #
      #   environment(nil, env: "development") do
      #     "config.autoload_paths += %W(#{config.root}/extras)"
      #   end
      def environment(data = nil, options = {})
        sentinel = /class [a-z_:]+ < Rails::Application/i
        env_file_sentinel = /Rails\.application\.configure do/
        data = yield if !data && block_given?

        in_root do
          if options[:env].nil?.map(&:camelcase).join('::')
            inject_into_file 'config/application.rb', "\n    #{data}", after: sentinel, verbose: false
          else
            Array(options[:env]).each do |env|
              inject_into_file "config/environments/#{env}.rb", "\n  #{data}", after: env_file_sentinel, verbose: false
            end
          end
        end
      end
      alias_method :application, :environment

      # Run a command in git.
      #
      #   git :init
      #   git add: "this.file that.rb"
      #   git add: "onefile.rb", rm: "badfile.cxx"
      def git(commands = {})
        if commands.is_a?(Symbol)
          run "git #{commands}"
        else
          commands.each do |cmd, options|
            run "git #{cmd} #{options}"
          end
        end
      end

      # Create a new file in the lib/ directory. Code can be specified
      # in a block or a data string can be given.
      #
      #   lib("crypto.rb") do
      #     "crypted_special_value = '#{rand}--#{Time.now}--#{rand(1337)}--'"
      #   end
      #
      #   lib("foreign.rb", "# Foreign code is fun")
      def lib(filename, data = nil, &block)
        log :lib, filename
        create_file("lib/#{filename}", data, verbose: false, &block)
      end

      # Create a new +Rakefile+ with the provided code (either in a block or a string).
      #
      #   rakefile("bootstrap.rake") do
      #     project = ask("What is the UNIX name of your project?")
      #
      #     <<-TASK
      #       namespace :#{project} do
      #         task :bootstrap do
      #           puts "I like boots!"
      #         end
      #       end
      #     TASK
      #   end
      #
      #   rakefile('seed.rake', 'puts "Planting seeds"')
      def rakefile(filename, data = nil, &block)
        log :rakefile, filename
        create_file("lib/tasks/#{filename}", data, verbose: false, &block)
      end

      # Generate something using a generator from Rails or a plugin.
      # The second parameter is the argument string that is passed to
      # the generator or an Array that is joined.
      #
      #   generate(:authenticated, "user session")
      def generate(what, *args)
        log :generate, what
        argument = args.flat_map(&:to_s).join(' ')

        in_root { run_ruby_script("bin/rails generate #{what} #{argument}", verbose: false) }
      end

      # Reads the given file at the source root and prints it in the console.
      #
      #   readme "README"
      def readme(path)
        log File.read(find_in_source_paths(path))
      end

      # Should probably move to its own file, these are general helpers rather than actions
      module Helpers
        # Returns the depth of the given file, where depth is the number of modules and classes it contains
        def internal_depth(file)
          depth = 0
          File.readlines(file).each do |line|
            if line =~ /^\s*(end|def)/
              return depth
            elsif line =~ /^\s*(module|class)/
              depth += 1
            end
          end
        end

        # Only executes the given block if the given file does not already define the given method, where the
        # block would normally go on to insert the method.
        #
        # See the ensure_define_sub_blocks method in the sub_blocks.rb generator for a usage example.
        def unless_has_method(filepath, name)
          unless File.read(filepath) =~ /^\s*def #{name}(\(|\s|\n)/
            yield
          end
        end

        # Executes the given block unless the given string is lower cased and underscored and doesn't start
        # with a number of contain any special characters
        def unless_valid_underscored_identifier(str)
          if str =~ /[^0-9a-z_]/ || str =~ /^[0-9]/
            yield
          end
        end

        def validate_resource_name(name)
          name.split('/').each do |n|
            unless_valid_underscored_identifier(n) do
              Origen.log.error "All parts of a resource name must be lower-cased, underscored and start with letter, '#{n}' is invalid"
              exit 1
            end
          end
        end

        # Converts a path to a resource identifier, by performing the following operations on the given path:
        #   1) Convert any absolute paths to relative
        #   2) Removes any leading part/, lib/ or application namespaces
        #   3) Remove any derivatives directories from the path
        #   3) Removes any trailing .rb
        #
        # Examples:
        #
        #   /my/code/my_app/app/parts/dut/derivatives/falcon   => dut/falcon
        #   app/lib/my_app/eagle.rb                            => eagle
        def resource_path(path)
          path = Pathname.new(path).expand_path.relative_path_from(Pathname.pwd).to_s.split('/')
          path.shift if path.first == 'app'
          path.shift if path.first == 'lib'
          path.shift if path.first == 'parts'
          path.shift if path.first == Origen.app.name.to_s
          path.delete('derivatives')
          path = path.join('/')
          path.sub('.rb', '')
          path
        end

        # Returns a Pathname to the part directory that should contain the given class name. No checking is
        # done of the name and it is assumed that it is a valid class name including the application namespace.
        def class_name_to_part_dir(name)
          name = name.split('::')
          name.shift  # Drop the application name
          dir = Origen.root.join('app', 'parts')
          name.each_with_index do |n, i|
            if i == 0
              dir = dir.join(n.underscore)
            else
              dir = dir.join('derivatives', n.underscore)
            end
          end
          dir
        end

        # Returns a Pathname to the lib directory file that should contain the given class name. No checking is
        # done of the name and it is assumed that it is a valid class name including the application namespace.
        def class_name_to_lib_file(name)
          name = name.split('::')
          dir = Origen.root.join('app', 'lib')
          name.each_with_index do |n, i|
            dir = dir.join(i == name.size - 1 ? "#{n.underscore}.rb" : n.underscore)
          end
          dir
        end

        def resource_path_to_part_dir(path)
          name = resource_path(path).split('/')   # Ensure this is clean, don't care about performance here
          dir = Origen.root.join('app', 'parts')
          name.each_with_index do |n, i|
            if i == 0
              dir = dir.join(n.underscore)
            else
              dir = dir.join('derivatives', n.underscore)
            end
          end
          dir
        end

        def resource_path_to_lib_file(path)
          name = resource_path(path).split('/')   # Ensure this is clean, don't care about performance here
          dir = Origen.root.join('app', 'lib', Origen.app.name.to_s)
          name.each_with_index do |n, i|
            dir = dir.join(i == name.size - 1 ? "#{n.underscore}.rb" : n.underscore)
          end
          dir
        end

        def resource_path_to_class(path)
          name = resource_path(path).split('/')   # Ensure this is clean, don't care about performance here
          name.unshift(Origen.app.name.to_s)
          name.map(&:camelcase).join('::')
        end
      end
      include Helpers

      protected

      # Define log for backwards compatibility. If just one argument is sent,
      # invoke say, otherwise invoke say_status. Differently from say and
      # similarly to say_status, this method respects the quiet? option given.
      def log(*args)
        if args.size == 1
          say args.first.to_s unless options.quiet?
        else
          args << (behavior == :invoke ? :green : :red)
          say_status(*args)
        end
      end

      def in_root
        Dir.chdir(Origen.root) do
          yield
        end
      end

      # Surround string with single quotes if there are no quotes,
      # otherwise fall back to double quotes
      def quote(value)
        return value.inspect unless value.is_a? String

        if value.include?("'")
          value.inspect
        else
          "'#{value}'"
        end
      end
    end
  end
end
