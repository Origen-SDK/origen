require 'active_support/concern'
module Origen
  module Tester
    autoload :J750,      'origen/tester/j750/j750'
    autoload :J750_HPT,  'origen/tester/j750/j750_hpt'
    autoload :Ultraflex, 'origen/tester/ultraflex/ultraflex'
    autoload :V93K,      'origen/tester/v93k/v93k'
    autoload :BDM,       'origen/tester/bdm/bdm'
    autoload :JLink,     'origen/tester/jlink/jlink'
    autoload :Doc,       'origen/tester/doc/doc'

    autoload :Vector,         'origen/tester/vector'
    autoload :VectorPipeline, 'origen/tester/vector_pipeline'
    autoload :CommandBasedTester, 'origen/tester/command_based_tester'
    autoload :Interface, 'origen/tester/interface'
    autoload :Generator, 'origen/tester/generator'
    autoload :Parser,    'origen/tester/parser'
    autoload :Time,      'origen/tester/time'

    extend ActiveSupport::Concern

    require 'origen/tester/vector_generator'
    require 'origen/tester/timing'
    require 'origen/tester/api'

    include VectoOrigenerator
    include Timing
    include API

    included do
    end

    module ClassMethods # :nodoc:
      # This overrides the new method of any class which includes this
      # module to force the newly created instance to be registered as
      # a tester with Origen
      def new(*args, &block) # :nodoc:
        if Origen.app.with_doc_tester?
          x = Origen::Tester::Doc.allocate
          if Origen.app.with_html_doc_tester?
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
      Origen.app.tester = self
    end
  end
end
