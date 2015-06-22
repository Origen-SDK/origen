module Origen
  module Tester
    module Parser
      autoload :SearchableArray, 'origen/tester/parser/searchable_array'
      autoload :SearchableHash,  'origen/tester/parser/searchable_hash'
      autoload :DescriptionLookup,  'origen/tester/parser/description_lookup'

      def parse(*args, &block)
        parser.parse(*args, &block)
      end

      # Returns a SearchableArray containing all tests parsed from flows, this is intended to
      # be the main API for accessing parsed test program attributes and should be a consistent
      # method that is implemented accross all tester models.
      #
      # Direct access to the underlying structure (which will be specific to the tester model)
      # can be achieved through the parser method, which returns an instance of J750::Parser
      #   $tester.parser.test_instances
      def tests
        parser.flow_items
      end
    end
  end
end
