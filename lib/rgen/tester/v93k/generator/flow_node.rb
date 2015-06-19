module RGen
  module Tester
    class V93K
      module Generator
        class FlowNode
          autoload :Run,  'rgen/tester/v93k/generator/flow_node/run'
          autoload :RunAndBranch,  'rgen/tester/v93k/generator/flow_node/run_and_branch'
          autoload :StopBin,  'rgen/tester/v93k/generator/flow_node/stop_bin'

          def collection
            @collection ||= []
          end
        end
      end
    end
  end
end
