module Origen
  module Tester
    module Parser
      class DescriptionLookup
        def initialize
          @store = { flow: {}, test: {}, usage: {} }
        end

        def for_flow(name, _options = {})
          k = flow_key(name)
          @store[:flow][k] || []
        end

        def for_test_definition(name, _options = {})
          n = name_key(name)
          @store[:test][n] || []
        end

        def for_test_usage(name, flow, _options = {})
          k = flow_key(flow)
          n = name_key(name)
          @store[:usage][k] ||= {}
          @store[:usage][k][n] || []
        end

        def add_for_flow(flow, description, _options = {})
          k = flow_key(flow)
          @store[:flow][k] ||= []
          [description].flatten.each do |d|
            @store[:flow][k] << d
          end
        end

        def add_for_test_definition(test, description, _option = {})
          n = name_key(test)
          @store[:test][n] ||= []
          [description].flatten.each do |d|
            @store[:test][n] << d
          end
        end

        def add_for_test_usage(test, flow, description, _option = {})
          k = flow_key(flow)
          n = name_key(test)
          @store[:usage][k] ||= {}
          @store[:usage][k][n] ||= []
          [description].flatten.each do |d|
            @store[:usage][k][n] << d
          end
        end

        private

        def flow_key(flow)
          Pathname.new(flow).basename('.*').to_s
        end

        def name_key(name)
          name.to_s.downcase
        end
      end
    end
  end
end
