require 'active_support/concern'

module Origen
  module Tester
    class Ultraflex
      module Generator
        extend ActiveSupport::Concern

        autoload :TestInstance,  'origen/tester/ultraflex/generator/test_instance'
        autoload :TestInstanceGroup,  'origen/tester/ultraflex/generator/test_instance_group'
        autoload :TestInstances, 'origen/tester/ultraflex/generator/test_instances'
        autoload :Patset,  'origen/tester/ultraflex/generator/patset'
        autoload :Patsets, 'origen/tester/ultraflex/generator/patsets'
        autoload :Patgroup,  'origen/tester/ultraflex/generator/patgroup'
        autoload :Patgroups, 'origen/tester/ultraflex/generator/patgroups'
        autoload :Flow,  'origen/tester/ultraflex/generator/flow'
        autoload :FlowLine,  'origen/tester/ultraflex/generator/flow_line'
        autoload :Placeholder, 'origen/tester/generator/placeholder'

        included do
          include Origen::Tester::Interface  # adds the interface helpers/Origen hook-up
          include Origen::Tester::Generator::FlowControlAPI::Interface
          PLATFORM = Origen::Tester::Ultraflex
        end

        def reset_globals
          flow.reset_globals
          @@test_instances_filename = nil
          @@patsets_filename = nil
          @@patgroups_filename = nil
          @@test_instances_filename = nil
          @@patsets_filename = nil
          @@patgroups_filename = nil
          @@test_instance_sheets = nil
          @@patset_sheets = nil
          @@flow_sheets = nil
          @@patgroup_sheets = nil
        end

        # Convenience method to allow the current name for the test instance,
        # patsets and patgroups sheets to be set to the same value.
        #
        #   # my ultraflex interface
        #
        #   resources_filename = "common"
        #
        #   # The above is equivalent to:
        #
        #   test_instances_filename = "common"
        #   patsets_filename = "common"
        #   patgroups_filename = "common"
        def resources_filename=(name)
          self.test_instances_filename = name
          self.patsets_filename = name
          self.patgroups_filename = name
        end

        # Set the name of the current test instances sheet. This does not change
        # the name of the current sheet, but rather sets the name of the sheet that
        # will be generated the next time you access test_instances.
        def test_instances_filename=(name)
          @@test_instances_filename = name
        end

        # Set the name of the current pattern sets sheet. This does not change
        # the name of the current sheet, but rather sets the name of the sheet that
        # will be generated the next time you access patsets.
        def patsets_filename=(name)
          @@patsets_filename = name
        end

        # Set the name of the current pattern groups sheet. This does not change
        # the name of the current sheet, but rather sets the name of the sheet that
        # will be generated the next time you access patgroups.
        def patgroups_filename=(name)
          @@patgroups_filename = name
        end

        # Returns the name of the current test instances sheet
        def test_instances_filename
          @@test_instances_filename ||= 'global'
        end

        # Returns the name of the current pat sets sheet
        def patsets_filename
          @@patsets_filename ||= 'global'
        end

        # Returns the name of the current pat groups sheet
        def patgroups_filename
          @@patgroups_filename ||= 'global'
        end

        # Returns a hash containing all test instance sheets
        def test_instance_sheets
          @@test_instance_sheets ||= {}
        end

        # Returns a hash containing all pat set sheets
        def patset_sheets
          @@patset_sheets ||= {}
        end

        # Returns a hash containing all flow sheets
        def flow_sheets
          @@flow_sheets ||= {}
        end

        # Returns a hash containing all pat group sheets
        def patgroup_sheets
          @@patgroup_sheets ||= {}
        end

        # Returns an array containing all sheet generators where a sheet generator is a flow,
        # test instance, patset or pat group sheet.
        # All Origen program generators must implement this method
        def sheet_generators # :nodoc:
          g = []
          [flow_sheets, test_instance_sheets, patset_sheets, patgroup_sheets].each do |sheets|
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

        # Returns the current test instances sheet (as defined by the current value of
        # test_instances_filename).
        #
        # Pass in a filename argument to have a specific sheet returned instead.
        #
        # If the sheet does not exist yet it will be created.
        def test_instances(filename = test_instances_filename)
          f = filename.to_sym
          return test_instance_sheets[f] if test_instance_sheets[f]
          t = TestInstances.new
          t.filename = f
          test_instance_sheets[f] = t
        end

        # Returns the current pattern sets sheet (as defined by the current value of
        # patsets_filename).
        #
        # Pass in a filename argument to have a specific sheet returned instead.
        #
        # If the sheet does not exist yet it will be created.
        def patsets(filename = patsets_filename)
          f = filename.to_sym
          return patset_sheets[f] if patset_sheets[f]
          p = Patsets.new
          p.filename = f
          patset_sheets[f] = p
        end
        alias_method :pat_sets, :patsets
        alias_method :pattern_sets, :patsets

        # Returns the current flow sheet (as defined by the name of the current top
        # level flow source file).
        #
        # Pass in a filename argument to have a specific sheet returned instead.
        #
        # If the sheet does not exist yet it will be created.
        def flow(filename = Origen.file_handler.current_file.basename('.rb').to_s)
          f = filename.to_sym
          return flow_sheets[f] if flow_sheets[f]
          p = Flow.new
          p.inhibit_output if Origen.interface.resources_mode?
          p.filename = f
          flow_sheets[f] = p
        end

        # Returns the current pattern groups sheet (as defined by the current value of
        # patgroups_filename).
        #
        # Pass in a filename argument to have a specific sheet returned instead.
        #
        # If the sheet does not exist yet it will be created.
        def patgroups(filename = patgroups_filename)
          f = filename.to_sym
          return patgroup_sheets[f] if patgroup_sheets[f]
          p = Patgroups.new
          p.filename = f
          patgroup_sheets[f] = p
        end
        alias_method :pat_groups, :patgroups
        alias_method :pattern_groups, :patgroups
      end
    end
  end
end
