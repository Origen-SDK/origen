require 'active_support/concern'

module Origen
  module Tester
    class V93K
      module Generator
        extend ActiveSupport::Concern

        autoload :Flow,  'origen/tester/v93k/generator/flow'
        autoload :FlowNode,  'origen/tester/v93k/generator/flow_node'
        autoload :TestFunction,  'origen/tester/v93k/generator/test_function'
        autoload :TestFunctions, 'origen/tester/v93k/generator/test_functions'
        autoload :TestMethod,  'origen/tester/v93k/generator/test_method'
        autoload :TestMethods, 'origen/tester/v93k/generator/test_methods'
        autoload :TestSuite,  'origen/tester/v93k/generator/test_suite'
        autoload :TestSuites, 'origen/tester/v93k/generator/test_suites'
        autoload :Pattern,  'origen/tester/v93k/generator/pattern'
        autoload :PatternMaster, 'origen/tester/v93k/generator/pattern_master'
        autoload :Placeholder, 'origen/tester/generator/placeholder'

        included do
          include Origen::Tester::Interface  # adds the interface helpers/Origen hook-up
          include Origen::Tester::Generator::FlowControlAPI::Interface
          PLATFORM = Origen::Tester::V93K
        end

        def flow
          return @flow if @flow
          @flow = Flow.new
          @flow.test_functions ||= TestFunctions.new(@flow)
          @flow.test_suites ||= TestSuites.new(@flow)
          @flow.test_methods ||= TestMethods.new(@flow)
          @flow
        end

        def pattern_master
          @pattern_master_file ||= PatternMaster.new
        end

        def test_functions
          flow.test_functions
        end

        def test_suites
          flow.test_suites
        end

        def test_methods
          flow.test_methods
        end

        def flow_sheets
          @@flow_sheets ||= {}
        end

        # Returns an array containing all sheet generators.
        # All Origen program generators must implement this method
        def sheet_generators # :nodoc:
          g = []
          [flow_sheets].each do |sheets|
            sheets.each do |_name, sheet|
              g << sheet
            end
          end
          g
        end

        # Returns an array containing all flow sheet generators.
        # All Origen program generators must implement this method
        def flow_generators
          g = []
          flow_sheets.each do |_name, sheet|
            g << sheet
          end
          g
        end
      end
    end
  end
end
