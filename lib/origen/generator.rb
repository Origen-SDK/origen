module Origen
  class Generator
    autoload :Pattern,         'origen/generator/pattern'
    autoload :Flow,            'origen/generator/flow'
    autoload :Resources,       'origen/generator/resources'
    autoload :Job,             'origen/generator/job'
    autoload :PatternFinder,   'origen/generator/pattern_finder'
    autoload :PatternIterator, 'origen/generator/pattern_iterator'
    autoload :Stage,           'origen/generator/stage'
    autoload :Compiler,        'origen/generator/compiler'
    autoload :Comparator,      'origen/generator/comparator'
    autoload :Renderer,        'origen/generator/renderer'

    class AbortError < StandardError; end

    def pattern
      @pattern ||= Pattern.new
    end

    def flow
      @flow ||= Flow.new
    end

    def resources
      @resources ||= Resources.new
    end

    def stage
      @stage ||= Stage.new
    end

    def generate_pattern(file, options)
      Job.new(file, options).run
    end

    def generate_program(file, options)
      Origen.file_handler.resolve_files(file, ignore_with_prefix: '_', default_dir: "#{Origen.root}/program") do |path|
        Origen.file_handler.current_file = path
        j = Job.new(path, options)
        j.pattern = path
        j.run
      end
      Origen.interface.write_files(options)
      unless options[:quiet] || Origen.tester.is_a?(OrigenTesters::Doc)
        if options[:referenced_pattern_list]
          file = "#{Origen.root}/list/#{options[:referenced_pattern_list]}"
        else
          file = Origen.config.referenced_pattern_list
        end
        puts "Referenced pattern list written to: #{Pathname.new(file).relative_path_from(Pathname.pwd)}"
        dir = Pathname.new(file).dirname
        FileUtils.mkdir_p(dir) unless dir.exist?
        File.open(file, 'w') do |f|
          Origen.interface.referenced_patterns.uniq.sort.each do |pat|
            f.puts pat
          end
        end
      end
    end

    def compile_file_or_directory(file, options)
      Job.new(file, { compile: true, default_dir: "#{Origen.root}/templates" }.merge(options)).run
    end

    def merge_file_or_directory(file, options)
      Job.new(file, options).run
    end

    def compiler
      @compiler ||= Compiler.new
    end

    def pattern_finder
      @pattern_finder ||= PatternFinder.new
    end

    def create_iterator
      iterator = PatternIterator.new
      Origen.after_app_loaded do |app|
        app.pattern_iterators << iterator
      end
      iterator
    end

    def option_pipeline
      @option_pipeline ||= []
    end
  end
end
