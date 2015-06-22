module Origen
  module Tester
    class Ultraflex
      class Parser
        class FlowLine
          attr_accessor :parser, :flow, :line

          TYPES = %w(
            Test characterize defaults enable-flow-word disable-flow-word error-print goto
            goto-on-all-done goto-on-all-lastfail goto-on-all-lastfaildoall logprint modify
            nop print reset set-device set-device-new set-error-bin set-retest-bin skip
            stop assign-integer create-integer delete-integer create-site-var assign-site-var
            flag-clear flag-clear-all flag-false flag-false-all flag-true flag-true-all
            state-clear-all state-false-all state-true-all
          )

          ATTRS = %w(
            label enable job part env opcode parameter
            tname tnum bin_pass bin_fail sort_pass sort_fail result flag_pass
            flag_fail state group_specifier group_sense group_condition group_name
            device_sense device_condition device_name debug_assume debug_sites
            comment
          )

          ALIASES = {
            bin:         :bin_fail,
            softbin:     :sort_fail,
            soft_bin:    :sort_fail,
            name:        :tname,
            number:      :tnum,
            test_number: :tnum,
            test_num:    :tnum,
            type:        :opcode
          }

          # Make readers for each low level attribute
          ATTRS.each do |attr|
            attr_reader attr
          end

          # And the aliases
          ALIASES.each do |_alias, attr|
            define_method("#{_alias}") do
              send(attr)
            end
          end

          # Returns the test instance called by the given line or nil
          def self.extract_test(line)
            l = new(line)
            if l.valid? && l.test?
              l.test_instance_name
            end
          end

          def initialize(line, options = {})
            @parser = options[:parser]
            @flow = options[:flow]
            @line = line
            parse
            if valid?
              ATTRS.each_with_index do |attr, i|
                instance_variable_set("@#{attr}", components[i + 1])
              end
            end
          end

          def inspect  # :nodoc:
            "<FlowLine: #{type}, Parameter: #{parameter}>"
          end

          def description
            from_instance = test_instance ? test_instance.description : ''
            from_flow = parser.descriptions.flow_line(name: test_instance_name, flow: flow.file)
            if !from_instance.empty? && !from_flow.empty?
              [from_instance, "\n", from_flow].flatten
            elsif from_instance.empty?
              from_flow
            else
              from_instance
            end
          end

          def parse
            @components = @line.split("\t") unless @line.strip.empty?
          end

          def valid?
            components[6] && TYPES.include?(components[6])
          end

          def components
            @components ||= []
          end

          def test?
            %w(Test characterize).include? opcode
          end

          def executes_under_context?(context)
            enable_conditions_met?(context) &&
              job_conditions_met?(context) &&
              part_conditions_met?(context) &&
              env_conditions_met?(context)
          end

          def enable_conditions_met?(context)
            conditions_met?(enable, context[:enable])
          end

          def job_conditions_met?(context)
            conditions_met?(job, context[:job])
          end

          def part_conditions_met?(context)
            conditions_met?(part, context[:part])
          end

          def env_conditions_met?(context)
            conditions_met?(env, context[:env])
          end

          def conditions_met?(conditions, values)
            if conditions.empty?
              true
            else
              values = [values].flatten
              conditions = conditions.split(',').map(&:strip)
              not_conditions = conditions.select { |c| c =~ /^!/ }
              conditions = conditions - not_conditions
              # Make sure all -ve conditions are not met
              if not_conditions.all? do |c|
                   c =~ /^!(.*)/
                   c = Regexp.last_match[1]
                   !values.include?(c)
                 end
                # And then any +ve conditions
                if conditions.empty?
                  true
                else
                  values.any? { |v| conditions.include?(v) }
                end
              else
                false
              end
            end
          end

          def test_instance_name
            parameter
          end
          alias_method :instance_name, :test_instance_name

          def test_instance
            instances = parser.test_instances.where(name: parameter, exact: true)
            if instances.size > 1
              puts "Warning multiple instances of #{name} found, using the first one"
            end
            if instances.size == 0
              nil
            else
              instances.first
            end
          end
          alias_method :instance, :test_instance

          # Returns an array of patterns used by the given test, if there are none
          # an empty array is returned.
          # Optionally supply patterns to exclude if you want to ignore common subroutine
          # patterns for example.
          def patterns(options = {})
            i = test_instance
            if i
              pats = i.patterns
              if options[:ignore] && pats
                pats.reject { |p| [options[:ignore]].flatten.include?(p) }
              else
                []
              end
            else
              []
            end
          end
          alias_method :pattern, :patterns

          # Returns a string summarizing any conditions (enable words, jobs, etc.) that
          # gate the execution of this line
          def conditions
            c = []
            c << "Enable: #{enable}" unless enable.empty?
            c << "Job: #{job}" unless job.empty?
            c << "Part: #{part}" unless part.empty?
            c << "Env: #{env}" unless env.empty?
            c.join('; ')
          end

          def vdd
            i = test_instance
            if i
              i.vdd
            end
          end
        end
      end
    end
  end
end
