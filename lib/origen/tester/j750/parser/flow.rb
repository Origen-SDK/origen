module Origen
  module Tester
    class J750
      class Parser
        class Flow < Origen::Tester::Parser::SearchableArray
          require 'pathname'

          attr_accessor :parser, :file

          def initialize(file, options = {})  # :nodoc:
            @parser = options[:parser]
            @file = Pathname.new(file)
            parse
          end

          def description
            @parser.descriptions.flow_summary(file: file)
          end
          alias_method :summary, :description

          # Returns the filename of the sheet that contained the current flow
          def filename
            @file.basename.to_s
          end
          alias_method :name, :filename

          # Returns all flow lines that are tests, optionally supply a context to
          # have only the test that will execute in that context returned
          #
          #   $tester.flow.first.tests.size
          #     => 20
          #   $tester.flow.first.tests(:job => "P1").size
          #     => 10
          #   $tester.flow.first.tests(:job => "P1", :enable => "data_collection").size
          #     => 15
          def tests(context = {})
            run_context(context)
          end

          # Returns all tests in the current flow, regardless of context
          def all_tests
            where(opcode: %w(Test characterize), exact: true)
          end

          def run_context(context)  # :nodoc:
            capture = true
            waiting_for_label = false
            select do |line|
              if capture
                if !waiting_for_label || waiting_for_label == line.label
                  waiting_for_label = false
                  case line.type
                  when 'Test', 'characterize'
                    line.executes_under_context?(context)
                  when 'set-device', 'stop'
                    capture = false if line.executes_under_context?(context)
                    false
                  when 'enable-flow-word'
                    if line.executes_under_context?(context)
                      context[:enable] = [context[:enable]].flatten
                      context[:enable] << line.parameter
                    end
                    false
                  when 'flag-true'
                    if line.executes_under_context?(context)
                      context[:true_flags] = [context[:true_flags]].flatten
                      context[:true_flags] << line.parameter
                    end
                    false
                  when 'flag-false'
                    if line.executes_under_context?(context)
                      context[:false_flags] = [context[:false_flags]].flatten
                      context[:false_flags] << line.parameter
                    end
                    false
                  when 'disable-flow-word'
                    if line.executes_under_context?(context)
                      context[:enable] = [context[:enable]].flatten
                      context[:enable].delete(line.parameter)
                    end
                    false
                  when 'logprint', 'nop', 'print'
                    false
                  when 'goto'
                    waiting_for_label = line.parameter
                    false
                  else
                    fail "Don't know how to process: #{line.type}, in file #{filename}"
                  end
                else
                  false
                end
              end
            end
          end

          def parse  # :nodoc:
            File.readlines(@file).each do |line|
              l = FlowLine.new(line, parser: parser, flow: self)
              self << l if l.valid?
            end
          end

          def inspect  # :nodoc:
            "<TestFlow: #{filename}, Lines: #{size}>"
          end
        end
      end
    end
  end
end
