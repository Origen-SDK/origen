require 'thor/group'

require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/inflections'

module Origen
  module CodeGenerators
    autoload :Base,            'origen/code_generators/base'
    autoload :Actions,         'origen/code_generators/actions'

    # Remove the color from output.
    def self.no_color!
      Thor::Base.shell = Thor::Shell::Basic
    end

    def self.origen_generators
      @origen_generators ||= {}
    end

    def self.plugin_generators
      @plugin_generators ||= {}
    end

    def self.load_generators
      return if @generators_loaded

      # Load Origen's generators
      require_relative 'code_generators/block_common'
      require_relative 'code_generators/dut'
      require_relative 'code_generators/block'
      require_relative 'code_generators/feature'
      require_relative 'code_generators/model'
      require_relative 'code_generators/klass'
      require_relative 'code_generators/module'
      # Load generators from plugins, TBD what the API will be here
      @generators_loaded = true
    end

    # Loaded separately so as not to pollute the generated list of generators available to users
    def self.load_internal_generators
      return if @internal_generators_loaded

      require_relative 'code_generators/semver'
      require_relative 'code_generators/timever'
      @internal_generators_loaded = true
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

    # Like invoke, but will also make internal-use only generators available
    # commands.
    def self.invoke_internal(name, args = ARGV, config = {})
      load_internal_generators
      invoke(name, args, config)
    end

    def self.find_by_name(name)
      names = name.split(':')
      case names.size
      when 1
        gen = origen_generators[names.first]
        return gen if gen
      when 2
        if names.first == 'origen'
          gen = origen_generators[names.first]
        else
          gen = plugin_generators[names.first][names.last]
        end
        return gen if gen
      end
      puts "Couldn't find a code generator named: #{name}"
      puts
      puts 'This is the list of available generators:'
      puts
      print_generators
      puts
    end

    # Show help message with available generators.
    def self.help(command = 'new')
      puts <<-END
Add pre-built features and code snippets to your application.

This command will generate code for your application to implement a given feature. In some
cases this will be a complete feature and in others it will provide a starting point for you
to further customize.

END
      puts "Usage: origen #{command} FEATURE [args] [options]"
      puts
      puts 'General options:'
      puts "  -h, [--help]     # Print feature's options and usage"
      puts '  -p, [--pretend]  # Run but do not make any changes'
      puts '  -f, [--force]    # Overwrite files that already exist'
      puts '  -s, [--skip]     # Skip files that already exist'
      puts '  -q, [--quiet]    # Suppress status output'
      puts
      puts "The available features are listed below, run 'origen new <feature> -h' for more info."
      puts

      print_generators
      puts
    end

    def self.print_generators
      load_generators
      origen_generators.each do |name, _gen|
        puts name
      end
      plugin_generators.each do |namespace, generators|
        next if namespace.to_s == 'origen_app_generators'

        puts
        generators.each do |_name, gen|
          puts "#{namespace}:#{gen}"
        end
      end
    end
  end
end
