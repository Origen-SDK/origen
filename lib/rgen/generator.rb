module RGen
  class Generator
    autoload :Pattern,         'rgen/generator/pattern'
    autoload :Flow,            'rgen/generator/flow'
    autoload :Resources,       'rgen/generator/resources'
    autoload :Job,             'rgen/generator/job'
    autoload :PatternFinder,   'rgen/generator/pattern_finder'
    autoload :PatternIterator, 'rgen/generator/pattern_iterator'
    autoload :Stage,           'rgen/generator/stage'
    autoload :Compiler,        'rgen/generator/compiler'
    autoload :Comparator,      'rgen/generator/comparator'
    autoload :Renderer,        'rgen/generator/renderer'

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
      RGen.file_handler.resolve_files(file, ignore_with_prefix: '_', default_dir: "#{RGen.root}/program") do |path|
        RGen.file_handler.current_file = path
        j = Job.new(path, options)
        j.pattern = path
        j.run
      end
      RGen.interface.write_files(options)
      unless options[:quiet] || RGen.tester.is_a?(RGen::Tester::Doc)
        if options[:referenced_pattern_list]
          file = "#{RGen.root}/list/#{options[:referenced_pattern_list]}"
        else
          file = RGen.config.referenced_pattern_list
        end
        puts "Referenced pattern list written to: #{Pathname.new(file).relative_path_from(Pathname.pwd)}"
        dir = Pathname.new(file).dirname
        FileUtils.mkdir_p(dir) unless dir.exist?
        File.open(file, 'w') do |f|
          RGen.interface.referenced_patterns.uniq.sort.each do |pat|
            f.puts pat
          end
        end
      end
    end

    def compile_file_or_directory(file, options)
      Job.new(file, { compile: true, default_dir: "#{RGen.root}/templates" }.merge(options)).run
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
      RGen.app.pattern_iterators << iterator
      iterator
    end

    def option_pipeline
      @option_pipeline ||= []
    end
  end
end
