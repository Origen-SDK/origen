module Origen
  module Tester
    class Doc
      # Class representing a program model, provides an API to iterate
      # on the flow based on context (e.g. which job).
      class Model
        attr_accessor :flows, :target

        def initialize
          @flows = {}
        end

        # Iterates through each line in the given flow returning a hash for each
        # line with the following structure:
        #
        #   {
        #     :type => Symbol,     # Type of flow line
        #     :description => [],  # Array of strings
        #     :instance => [{}],   # Array of attributes hashes (each one represents an individual test instance)
        #     :flow => {},         # Hash of attributes
        #     :context => {},      # Hash of attributes
        #   }
        #
        # In all cases if an item is missing then it will be replaced by an empty
        # array or hash as appropriate so that the caller does not need to worry
        # about this.
        #
        # Supply the name of the flow(s) to consider, if the flows argument is left
        # out then all lines in all flows will be returned.
        #
        # A context option can be supplied to only return the tests for which the given
        # context is true.
        #
        #   puts "The following tests run at FR:"
        #   program_model.each_in_flow(:ft_flow, :context => { :job => "FR" }) do |line|
        #     puts "  #{line[:flow][:name]}"
        #   end
        def each_in_flow(flows = nil, options = {})
          if flows.is_a?(Hash)
            options = flows
            flows = nil
          end
          unless flows
            flows = self.flows.keys
          end
          [flows].flatten.each do |flow|
            @flows[flow.to_sym].each do |test|
              test = format_test(test)
              if valid_in_context?(test, options[:context])
                yield test
              end
            end
          end
          nil
        end

        # Searches the given flows to find dependents of the given test id. The dependents
        # are returned in arrays grouped by context:
        #
        #   {
        #     :if_failed => [],
        #     :if_passed => [],
        #     :if_ran => [],
        #     :unless_ran => [],
        #   }
        #
        # Each test will have the same format as described in #each_in_flow.
        #
        # If no dependents are found an empty hash is returned.
        def dependents_of(id, flows, options = {})
          d = {}
          each_in_flow(flows, options) do |test|
            test[:context].each do |key, val|
              if val == id
                d[key] ||= []
                d[key] << test
              end
            end
          end
          d
        end

        # Search for the given test id in the given flows.
        # Returns nil if not found.
        def find_by_id(id, flows, options = {})
          each_in_flow(flows, options) do |test|
            return test if test[:flow][:id] == id
          end
        end

        # Returns true if the given tests id valid under the given context
        # (currently only tests for job matching)
        def valid_in_context?(test, context = nil)
          if context && context[:job] && test[:context]
            if test[:context][:if_jobs]
              test[:context][:if_jobs].include?(context[:job])
            elsif test[:context][:unless_jobs]
              !test[:context][:unless_jobs].include?(context[:job])
            else
              true
            end
          else
            true
          end
        end

        # @api private
        def format_test(test, _options = {})
          {
            type:        test[:type] ? test[:type].to_sym : :unknown,
            description: test[:description] || [],
            instance:    build_instance(test),
            flow:        test[:flow] ? test[:flow][:attributes] || {} : {},
            context:     test[:flow] ? test[:flow][:context] || {} : {}
          }
        end

        # @api private
        def build_instance(test)
          if test[:instance]
            if test[:instance][:group]
              test[:instance][:group].map { |g| g[:attributes] || {} }
            else
              [test[:instance][:attributes] || {}]
            end
          else
            [{}]
          end
        end

        # YAML likes strings for keys, we don't, so make sure all keys are symbols
        # when receiving a new flow
        # @api private
        def add_flow(name, content)
          @flows[name.to_sym] = content.map do |h|
            h = symbolize_keys h
            if h[:instance] && h[:instance][:group]
              h[:instance][:group] = h[:instance][:group].map { |j| symbolize_keys j }
            end
            h
          end
        end

        # @api private
        def symbolize_keys(hash)
          hash.reduce({}) do |result, (key, value)|
            new_key = case key
                      when String then key.to_sym
                      else key
                      end
            new_value = case value
                        when Hash then symbolize_keys(value)
                        else value
                        end
            result[new_key] = new_value
            result
          end
        end
      end
    end
  end
end
