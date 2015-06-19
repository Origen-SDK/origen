require 'active_support/concern'

module RGen
  module Tester
    class V93K
      module Generator
        extend ActiveSupport::Concern

        autoload :Flow,  'rgen/tester/v93k/generator/flow'
        autoload :FlowNode,  'rgen/tester/v93k/generator/flow_node'
        autoload :TestFunction,  'rgen/tester/v93k/generator/test_function'
        autoload :TestFunctions, 'rgen/tester/v93k/generator/test_functions'
        autoload :TestMethod,  'rgen/tester/v93k/generator/test_method'
        autoload :TestMethods, 'rgen/tester/v93k/generator/test_methods'
        autoload :TestSuite,  'rgen/tester/v93k/generator/test_suite'
        autoload :TestSuites, 'rgen/tester/v93k/generator/test_suites'
        autoload :Pattern,  'rgen/tester/v93k/generator/pattern'
        autoload :PatternMaster, 'rgen/tester/v93k/generator/pattern_master'
        autoload :Placeholder, 'rgen/tester/generator/placeholder'

        included do
          include RGen::Tester::Interface  # adds the interface helpers/RGen hook-up
          include RGen::Tester::Generator::FlowControlAPI::Interface
          PLATFORM = RGen::Tester::V93K
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
        # All RGen program generators must implement this method
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
        # All RGen program generators must implement this method
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
