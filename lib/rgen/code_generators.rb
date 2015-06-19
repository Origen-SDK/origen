require 'thor/group'

require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/inflections'

module RGen
  module CodeGenerators
    autoload :Base,            'rgen/code_generators/base'
    autoload :Actions,         'rgen/code_generators/actions'

    # Remove the color from output.
    def self.no_color!
      Thor::Base.shell = Thor::Shell::Basic
    end

    def self.rgen_generators
      @rgen_generators ||= {}
    end

    def self.plugin_generators
      @plugin_generators ||= {}
    end

    def self.load_generators
      return if @generators_loaded
      # Load RGen's generators
      Dir.glob("#{RGen.top}/lib/rgen/code_generators/**/*.rb").sort.each do |file|
        require file
      end
      # Load generators from plugins, TBD what the rules will be here
      @generators_loaded = true
    end

    # Receives a namespace, arguments and the behavior to invoke the generator.
    # It's used as the default entry point for generate, destroy and update
    # commands.
    def self.invoke(name, args = ARGV, config = {})
      load_generators
      if klass = find_by_name(name)
        args << '--help' if args.empty? && klass.arguments.any?(&:required?)
        klass.start(args, config)
      end
    end

    def self.find_by_name(name)
      names = name.split(':')
      case names.size
      when 1
        gen = rgen_generators[names.first]
        return gen if gen
      when 2
        if names.first == 'rgen'
          gen = rgen_generators[names.first]
        else
          gen = plugin_generators[names.first][names.last]
        end
        return gen if gen
      end
      puts "Couldn't find a feature generator named: #{name}"
      puts
      puts 'This is the list of available features:'
      puts
      print_generators
      puts
    end

    # Show help message with available generators.
    def self.help(command = 'add')
      puts <<-END
Add pre-built features and code snippets.

This command will add pre-built code to your application to implement a given feature. In some
cases this will be a complete feature and in others it will provide a starting point for you
to further customize.

END
      puts "Usage: rgen #{command} FEATURE [args] [options]"
      puts
      puts 'General options:'
      puts "  -h, [--help]     # Print feature's options and usage"
      puts '  -p, [--pretend]  # Run but do not make any changes'
      puts '  -f, [--force]    # Overwrite files that already exist'
      puts '  -s, [--skip]     # Skip files that already exist'
      puts '  -q, [--quiet]    # Suppress status output'
      puts
      puts "The available features are listed below, run 'rgen add <feature> -h' for more info."
      puts

      print_generators
      puts
    end

    def self.print_generators
      load_generators
      rgen_generators.each do |name, _gen|
        puts name
      end
      plugin_generators.each do |namespace, generators|
        puts
        generators.each do |_name, gen|
          puts "#{namespace}:#{gen}"
        end
      end
    end
  end
end
