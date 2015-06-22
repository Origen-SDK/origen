module Origen
  module Tester
    class J750
      module Generator
        class TestInstances
          include Origen::Tester::Generator

          TEMPLATE = "#{Origen.top}/lib/origen/tester/j750/generator/templates/instances.txt.erb"
          OUTPUT_POSTFIX = 'instances'

          class IndexedString < ::String
            attr_accessor :index

            def name
              self
            end
          end

          def add(name, type, options = {})
            options = {
              test_instance_class: TestInstance
            }.merge(options)
            ins = options.delete(:test_instance_class).new(name, type, options)
            if @current_group
              @current_group << ins
            else
              collection << ins
            end
            c = Origen.interface.consume_comments
            Origen.interface.descriptions.add_for_test_definition(name, c)
            ins
          end

          # IG-XL doesn't have a formal instance group type and instead declares them anonymously
          # whenever test instances of the same name appear consecutively in the test instance sheet.
          # However when it comes to generating a test program life becomes much easier if we have
          # a way to explicitly declare instances as part of a group - this makes duplicate tracking
          # and sorting of the test instance sheet much easier.
          #
          # Use this method to generate instance groups via a block. Within the the block you should
          # generate instances as normal and they will automatically be assigned to the current group.
          # Note that the name of the instances generated within the group is discarded and replaced
          # with the name of the group. Origen automatically appends "grp" to this name to highlight
          # instances that were generated as part of the group.
          #
          #   test_instances.group("erase_all_blocks") do |group|
          #     # Generate instances here as normal
          #     test_instances.functional("erase_blk0")
          #     test_instances.functional("erase_blk1")
          #   end
          #
          # The group object is passed into the block but usually you should not need to interact
          # with this directly except maybe to set the name if it is not yet established at the point
          # where the group is initiated:
          #
          #   test_instances.group do |group|
          #     # Generate instances here as normal
          #     group.name = "group_blah"
          #   end
          #
          # A common way to generate groups is to create a helper method in your application which
          # is responsible for creating groups as required:
          #
          #   def group_wrapper(name, options)
          #     if options[:by_block]
          #       test_instances.group(name) do |group|
          #         yield group
          #       end
          #     else
          #       yield
          #     end
          #   end
          #
          # In that case the group argument becomes quite useful for branching based on whether you
          # are generating a group or standalone instances:
          #
          #  group_wrapper(name, options) do |group|
          #    if group
          #      # Generate group instances
          #    else
          #      # Generate standalone instances
          #    end
          #  end
          def group(name = nil, options = {})
            name, options = nil, name if name.is_a?(Hash)
            @current_group = TestInstanceGroup.new(name, options)
            collection << @current_group
            yield @current_group
            @current_group = nil
          end
          alias_method :add_group, :group

          def finalize(_options = {}) # :nodoc:
            uniq!
            sort!
          end

          def uniq! # :nodoc:
            uniques = []
            versions = {}
            multi_version_tests = {}
            collection.each do |instance|
              # If a uniquely named instance is found add it, otherwise update the version
              # of the current instance to match that of the existing instance that it duplicates
              unless uniques.any? do |i|
                if i == instance
                  instance.version = i.version
                  true
                else
                  false
                end
              end
                if instance.respond_to?(:version=)
                  versions[instance.unversioned_name] ||= 0
                  versions[instance.unversioned_name] += 1
                  if versions[instance.unversioned_name] > 1
                    multi_version_tests[instance.unversioned_name] = true
                  end
                  instance.version = versions[instance.unversioned_name]
                end
                uniques << instance
              end
            end
            # This final loop disables the version identifier for tests that have only a single version,
            # this makes it clearer when multiple versions exist - whenever you see a v1 you know there
            # is at least a v2 also.
            collection.map! do |instance|
              if instance.respond_to?(:version=)
                unless multi_version_tests[instance.unversioned_name]
                  instance.append_version = false
                end
              end
              instance
            end
            self.collection = uniques
          end

          def sort! # :nodoc:
            # Present the instances in the final sheet in alphabetical order
            collection.map!.with_index do |ins, _i|
              if ins.is_a?(String)   # Can happen if content has been rendered in from a template
                ins = IndexedString.new(ins)
              end
              ins
            end
            collection.sort! { |a, b| [a.name.to_s] <=> [b.name.to_s] }
          end

          def bpmu(name, options = {})
            add(name, :board_pmu, options)
          end
          alias_method :board_pmu, :bpmu

          def ppmu(name, options = {})
            add(name, :pin_pmu, options)
          end
          alias_method :pin_pmu, :ppmu

          def functional(name, options = {})
            add(name, :functional, options)
          end

          def empty(name, options = {})
            add(name, :empty, options)
          end

          def other(name, options = {})
            add(name, :other, options)
          end

          def apmu_powersupply(name, options = {})
            add(name, :apmu_powersupply, options)
          end

          def mto_memory(name, options = {})
            add(name, :mto_memory, options)
          end
        end
      end
    end
  end
end
