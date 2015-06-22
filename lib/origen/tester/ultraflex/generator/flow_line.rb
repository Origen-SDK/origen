module Origen
  module Tester
    class Ultraflex
      module Generator
        class FlowLine
          attr_accessor :type, :id, :cz_setup # cz_setup is a virtual attrib since it is not part of the regular flow line
          # cz_setup combine with instance name when characterize opcode is used

          # Attributes for each flow line, these must be declared in the order they are to be output
          ATTRS = %w(label enable job part env opcode parameter tname tnum bin_pass bin_fail
                     sort_pass sort_fail result flag_pass flag_fail state
                     group_specifier group_sense group_condition group_name
                     device_sense device_condition device_name
                     debug_assume debug_sites comment
                  )

          # Map any aliases to the official names here, multiple aliases for a given attribute
          # are allowed
          ALIASES = {
            bin:            :bin_fail,
            softbin:        :sort_fail,
            soft_bin:       :sort_fail,
            name:           :tname,
            number:         :tnum,
            if_enable:      :enable,
            if_enabled:     :enable,
            enabled:        :enable,
            # Aliases can also be used to set defaults on multiple attributes like this,
            # use :value to refer to the value passed in to the given alias
            flag_false:     { device_condition: 'flag-false',
                              device_name:      :value
                           },
            flag_true:      { device_condition: 'flag-true',
                              device_name:      :value
                           },
            flag_false_any: { group_specifier: 'any-active',
                              group_condition: 'flag-false',
                              group_name:      :value
                               },
            flag_false_all: { group_specifier: 'all-active',
                              group_condition: 'flag-false',
                              group_name:      :value
                               },
            flag_true_any:  { group_specifier: 'any-active',
                              group_condition: 'flag-true',
                              group_name:      :value
                              },
            flag_true_all:  { group_specifier: 'all-active',
                              group_condition: 'flag-true',
                              group_name:      :value
                              },
            flag_clear:     { device_condition: 'flag-clear',
                              device_name:      :value
                           }
          }

          # Assign attribute defaults here, generally this should match whatever defaults
          # Teradyne has set whenever you create a new test instance, etc.
          DEFAULTS = {
            test:              {
              opcode: 'Test',
              result: 'Fail'
            },
            cz:                {
              opcode: 'characterize',
              result: 'None'
            },
            goto:              {
              opcode: 'goto'
            },
            nop:               {
              opcode: 'nop'
            },
            set_device:        {
              opcode: 'set-device'
            },
            enable_flow_word:  {
              opcode: 'enable-flow-word'
            },
            disable_flow_word: {
              opcode: 'disable-flow-word'
            },
            logprint:          {
              opcode: 'logprint'
            }
          }

          # Generate accessors for all attributes and their aliases
          ATTRS.each do |attr|
            attr_accessor attr.to_sym
          end

          ALIASES.each do |_alias, val|
            if val.is_a? Hash
              define_method("#{_alias}=") do |v|
                val.each do |k, _v|
                  myval = _v == :value ? v : _v
                  send("#{k}=", myval)
                end
              end
            else
              define_method("#{_alias}=") do |v|
                send("#{val}=", v)
              end
              define_method("#{_alias}") do
                send(val)
              end
            end
          end

          def initialize(type, attrs = {})
            @ignore_missing_instance = attrs.delete(:instance_not_available)
            self.cz_setup = attrs.delete(:cz_setup)
            @type = type
            # Set the defaults
            DEFAULTS[@type.to_sym].each do |k, v|
              send("#{k}=", v) if self.respond_to?("#{k}=")
            end
            # Then the values that have been supplied
            attrs.each do |k, v|
              send("#{k}=", v) if self.respond_to?("#{k}=")
            end
          end

          def parameter=(value)
            if (@type == :test || @test == :cz) && !@ignore_missing_instance
              if value.is_a?(String) || value.is_a?(Symbol)
                fail "You must supply the actual test instance object for #{value} when adding it to the flow"
              end
            end
            @parameter = value
          end

          def parameter
            # When referring to the test instance take the opportunity to refresh the current
            # version of the test instance
            @parameter = Origen.interface.identity_map.current_version_of(@parameter)
          end

          # Returns the fully formatted flow line for insertion into a flow sheet
          def to_s
            l = "\t"
            ATTRS.each do |attr|
              if attr == 'parameter'
                ins = parameter
                if ins.respond_to?(:name)
                  l += "#{ins.name}"
                else
                  l += "#{ins}"
                end
                if cz_setup
                  l += " #{cz_setup}\t"
                else
                  l += "\t"
                end
              else
                l += "#{send(attr)}\t"
              end
            end
            "#{l}"
          end

          def job
            if !if_jobs.empty? && !unless_jobs.empty?
              fail "Both if and unless jobs have been defined for test: #{parameter}"
            elsif !if_jobs.empty?
              if_jobs.join(',')
            elsif !unless_jobs.empty?
              unless_jobs.map { |j| "!#{j}" }.join(',')
            else
              ''
            end
          end
          alias_method :jobs, :job

          def unless_enable=(*_args)
          end
          alias_method :unless_enabled=, :unless_enable=

          def if_jobs
            @if_jobs ||= []
          end

          def unless_jobs
            @unless_jobs ||= []
          end

          def if_job=(jobs)
            [jobs].flatten.compact.each do |job|
              job = job.to_s.upcase
              if job =~ /!/
                self.unless_job = job
              else
                if_jobs << job unless if_jobs.include?(job)
              end
            end
          end
          alias_method :if_jobs=, :if_job=
          alias_method :add_if_jobs, :if_job=
          alias_method :add_if_job, :if_job=

          def unless_job=(jobs)
            [jobs].flatten.compact.each do |job|
              job = job.to_s.upcase
              job.gsub!('!', '')
              unless_jobs << job unless unless_jobs.include?(job)
            end
          end
          alias_method :unless_jobs=, :unless_job=
          alias_method :add_unless_jobs, :unless_job=
          alias_method :add_unless_job, :unless_job=

          def continue_on_fail
            self.result = 'None'
          end

          def set_flag_on_fail
            self.flag_fail = "#{id}_FAILED"
          end

          def set_flag_on_pass
            self.flag_pass = "#{id}_PASSED"
          end

          def set_flag_on_ran
            self.flag_pass = "#{id}_RAN"
          end

          def run_if_any_passed(parent)
            parent.continue_on_fail
            self.flag_true_any = parent.set_flag_on_pass
          end

          def run_if_all_passed(parent)
            parent.continue_on_fail
            self.flag_true_all = parent.set_flag_on_pass
          end

          def run_if_any_failed(parent)
            parent.continue_on_fail
            self.flag_true_any = parent.set_flag_on_fail
          end

          def run_if_all_failed(parent)
            parent.continue_on_fail
            self.flag_true_all = parent.set_flag_on_fail
          end

          def id
            @id || "#{parameter}_#{unique_counter}"
          end

          def unique_counter
            @unique_counter ||= self.class.unique_counter
          end

          def self.unique_counter
            @ix ||= -1
            @ix += 1
          end

          def test?
            @type == :test
          end
        end
      end
    end
  end
end
