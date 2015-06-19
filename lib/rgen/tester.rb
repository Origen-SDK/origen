require 'active_support/concern'
module RGen
  module Tester
    autoload :J750,      'rgen/tester/j750/j750'
    autoload :J750_HPT,  'rgen/tester/j750/j750_hpt'
    autoload :Ultraflex, 'rgen/tester/ultraflex/ultraflex'
    autoload :V93K,      'rgen/tester/v93k/v93k'
    autoload :BDM,       'rgen/tester/bdm/bdm'
    autoload :JLink,     'rgen/tester/jlink/jlink'
    autoload :Doc,       'rgen/tester/doc/doc'

    autoload :Vector,         'rgen/tester/vector'
    autoload :VectorPipeline, 'rgen/tester/vector_pipeline'
    autoload :CommandBasedTester, 'rgen/tester/command_based_tester'
    autoload :Interface, 'rgen/tester/interface'
    autoload :Generator, 'rgen/tester/generator'
    autoload :Parser,    'rgen/tester/parser'
    autoload :Time,      'rgen/tester/time'

    extend ActiveSupport::Concern

    require 'rgen/tester/vector_generator'
    require 'rgen/tester/timing'
    require 'rgen/tester/api'

    include VectorGenerator
    include Timing
    include API

    included do
    end

    module ClassMethods # :nodoc:
      # This overrides the new method of any class which includes this
      # module to force the newly created instance to be registered as
      # a tester with RGen
      def new(*args, &block) # :nodoc:
        if RGen.app.with_doc_tester?
          x = RGen::Tester::Doc.allocate
          if RGen.app.with_html_doc_tester?
            x.html_mode = true
          end
        else
          x = allocate
        end
        x.send(:initialize, *args, &block)
        x.register_tester
        x
      end
    end

    def register_tester # :nodoc:
      RGen.app.tester = self
    end
  end
end
