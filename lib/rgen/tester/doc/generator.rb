require 'active_support/concern'

module RGen
  module Tester
    class Doc
      module Generator
        extend ActiveSupport::Concern

        autoload :Test,  'rgen/tester/doc/generator/test'
        autoload :TestGroup,  'rgen/tester/doc/generator/test_group'
        autoload :Tests, 'rgen/tester/doc/generator/tests'
        autoload :Flow,  'rgen/tester/doc/generator/flow'
        autoload :FlowLine,  'rgen/tester/doc/generator/flow_line'
        autoload :Placeholder, 'rgen/tester/generator/placeholder'

        included do
          include RGen::Tester::Interface  # adds the interface helpers/RGen hook-up
          include RGen::Tester::Generator::FlowControlAPI::Interface
          PLATFORM = RGen::Tester::Doc
        end

        # Returns the current flow (as defined by the name of the current top
        # level flow source file).
        #
        # Pass in a filename argument to have a specific flow returned instead.
        #
        # If the flow does not exist yet it will be created.
        def flow(filename = nil)
          unless filename
            if RGen.file_handler.current_file
              filename = RGen.file_handler.current_file.basename('.rb').to_s
            else
              filename = 'anonymous'
            end
          end
          f = filename.to_sym
          return flows[f] if flows[f]
          p = Flow.new
          p.inhibit_output if RGen.interface.resources_mode?
          p.filename = f
          flows[f] = p
        end

        # @api private
        def at_flow_start
        end

        # @api private
        def at_run_start
          flow.at_run_start
          @@tests = nil
          @@flows = nil
        end
        alias_method :reset_globals, :at_run_start

        # Returns a container for all generated tests.
        def tests
          @@tests ||= Tests.new
        end
        alias_method :test_instances, :tests

        # Returns a hash containing all flows
        def flows
          @@flows ||= {}
        end

        # Returns an array containing all sheet generators where a sheet generator is a flow,
        # test instance, patset or pat group sheet.
        # All RGen program generators must implement this method
        def sheet_generators # :nodoc:
          g = []
          [flows].each do |sheets|
            sheets.each do |_name, sheet|
              g << sheet
            end
          end
          g
        end

        # Returns an array containing all flow generators.
        # All RGen program generators must implement this method
        def flow_generators
          g = []
          flows.each do |_name, sheet|
            g << sheet
          end
          g
        end

        # The source of all program files is passed in here before executing.
        # This will replace all comments with a method call containing the comment so that
        # they can be captured.
        def filter_source(source) # :nodoc:
          src = ''
          source.split(/\r?\n/).each do |line|
            if line !~ /^\s*#-/ && line =~ /^\s*#(.*)/
              comment = Regexp.last_match[1].gsub("'", "\\\\'")
              src << "RGen.interface.doc_comments_capture('#{comment}')\n"
            else
              src << "#{line}\n"
            end
          end
          src
        end

        def doc_comments_capture(comment)
          doc_comments << "#{comment}"
        end

        def doc_comments
          @doc_comments ||= []
        end

        def doc_comments_consume
          c = doc_comments
          doc_comments_discard
          c
        end

        def doc_comments_discard
          @doc_comments = []
        end
      end
    end
  end
end
