module RGen
  module Tester
    module Generator
      class Placeholder
        attr_accessor :type, :file, :options, :id

        def initialize(type, file, options = {})
          @type, @file, @options = type, file, options
        end
      end
    end
  end
end
