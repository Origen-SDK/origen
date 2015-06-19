module RGen
  module Tester
    class Doc
      module Generator
        class FlowLine
          attr_accessor :type, :id, :test, :context, :attributes, :description

          def initialize(type, attrs = {})
            @type = type
            @test = attrs.delete(:test)
            @context = {}
            @attributes = {}
            flow_control_options = RGen.interface.extract_flow_control_options!(attrs)
            flow_control_options.each do |opt, val|
              send("#{opt}=", val)
            end
            attrs.each do |attribute, val|
              @attributes[attribute] = val
            end
          end

          def to_yaml(options = {})
            options = {
              include_descriptions: true
            }.merge(options)
            y = {
              'type'        => @type,
              'description' => description,
              'instance'    => test_to_yaml(options),
              'flow'        => {
                'attributes' => attributes_to_yaml(options),
                'context'    => context_to_yaml(options)
              }
            }
            y.delete('description') unless options[:include_descriptions]
            y
          end

          def attributes_to_yaml(_options = {})
            a = {}
            @attributes.each do |name, val|
              a[name.to_s] = val if val
            end
            a
          end

          def context_to_yaml(_options = {})
            # Turn attribute keys into strings for prettier yaml, this includes all
            # relationship meta data
            c = @context.reduce({}) { |memo, (k, v)| memo[k.to_s] = v; memo }
            # Now add job/enable word data
            if @enable
              c['if_enable'] = @enable
            end
            if @unless_enable
              c['unless_enable'] = @unless_enable
            end
            unless if_jobs.empty?
              c['if_jobs'] = if_jobs
            end
            unless unless_jobs.empty?
              c['unless_jobs'] = unless_jobs
            end
            c
          end

          def test_to_yaml(options = {})
            if @test
              if @test.is_a?(String) || @test.is_a?(Symbol)
                {
                  'attributes' => {
                    'name' => @test.to_s
                  }
                }
              else
                @test.to_yaml(options)
              end
            end
          end

          def method_missing(method, *args, &_block)
            method = method.to_s
            if method.gsub!('=', '')
              @attributes[method] = args.first
            else
              @attributes[method]
            end
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

          def if_jobs
            @if_jobs ||= []
          end

          def unless_jobs
            @unless_jobs ||= []
          end

          def if_enable=(val)
            @enable = val
          end
          alias_method :enable=, :if_enable=
          alias_method :if_enabled=, :if_enable=

          def unless_enable=(val)
            @unless_enable = val
          end
          alias_method :unless_enabled=, :unless_enable=

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

          def run_if_failed(id)
            @context[:if_failed] = id
          end

          def run_if_passed(id)
            @context[:if_passed] = id
          end

          def run_if_ran(id)
            @context[:if_ran] = id
          end

          def run_unless_ran(id)
            @context[:unless_ran] = id
          end

          def run_if_any_passed(parent)
            @context[:if_any_passed] = parent.id
          end

          def run_if_all_passed(parent)
            @context[:if_all_passed] = parent.id
          end

          def run_if_any_failed(parent)
            @context[:if_any_failed] = parent.id
          end

          def run_if_all_failed(parent)
            @context[:if_all_failed] = parent.id
          end

          def continue_on_fail
            @attributes[:continue] = true
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
