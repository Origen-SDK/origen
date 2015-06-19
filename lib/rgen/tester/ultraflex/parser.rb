module RGen
  module Tester
    class Ultraflex
      class Parser
        autoload :Flows,   'rgen/tester/ultraflex/parser/flows'
        autoload :Flow,   'rgen/tester/ultraflex/parser/flow'
        autoload :FlowLine,   'rgen/tester/ultraflex/parser/flow_line'
        autoload :TestInstances,   'rgen/tester/ultraflex/parser/test_instances'
        autoload :TestInstance,   'rgen/tester/ultraflex/parser/test_instance'
        autoload :PatternSets,   'rgen/tester/ultraflex/parser/pattern_sets'
        autoload :PatternSet,   'rgen/tester/ultraflex/parser/pattern_set'
        autoload :DCSpecs,   'rgen/tester/ultraflex/parser/dc_specs'
        autoload :DCSpec,   'rgen/tester/ultraflex/parser/dc_spec'
        autoload :ACSpecs,   'rgen/tester/ultraflex/parser/ac_specs'
        autoload :ACSpec,   'rgen/tester/ultraflex/parser/ac_spec'
        autoload :Descriptions,   'rgen/tester/ultraflex/parser/descriptions'

        def reset
          @flows = nil
          @test_instances = nil
          @pattern_sets = nil
          @dc_specs = nil
          @ac_specs = nil
        end

        def descriptions
          @descriptions ||= Descriptions.new(parser: self)
        end

        # Returns an array of test flows
        def flows
          @flows ||= Flows.new(parser: self)
        end

        def test_instances
          @test_instances ||= TestInstances.new(parser: self)
        end
        alias_method :instances, :test_instances

        def pattern_sets
          @pattern_sets ||= PatternSets.new(parser: self)
        end
        alias_method :patsets, :pattern_sets
        alias_method :pat_sets, :pattern_sets

        def dc_specs
          @dc_specs ||= DCSpecs.new(parser: self)
        end

        def ac_specs
          @ac_specs ||= ACSpecs.new(parser: self)
        end

        def inspect
          "<Parsed Program: Flows: #{flows.size}>"
        end

        # Parse a file, array of files, or a directory.
        #
        # This can be called multiple times to add new files to the
        # program model.
        def parse(file)
          RGen.log.info ''
          RGen.log.info "Parsing Ultraflex test program from: #{file}"
          RGen.log.info ''
          reset
          # Note use of local file handler here, this should be how it is
          # done globally, otherwise we can run into hard to debug problems
          # due to state/reference dir changes in the single RGen.file_handler
          RGen::FileHandler.new.resolve_files(file) do |f|
            parse_file(f)
          end
          RGen.log.info ''
          self
        end

        def parse_file(file)
          line = File.readlines(file).first
          begin
            if line =~ /Flow Table/
              flows.import(file)
            elsif line =~ /Instances/
              test_instances.import(file)
            elsif line =~ /Pattern Sets/
              patsets.import(file)
            elsif line =~ /DC Spec/
              dc_specs.import(file)
            else
              puts "Skipped (un-supported file type): #{file}"
            end
          rescue Exception => e
            if e.is_a?(ArgumentError) && e.message =~ /invalid byte sequence/
              puts "Skipped (not ASCII): #{file}"
            else
              puts e.message
              puts e.backtrace
              exit 1
            end
          end
        end
      end
    end
  end
end
