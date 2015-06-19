module RGen
  class Generator
    class Flow
      attr_accessor :top_level

      def create(options = {}, &block)
        # Refresh the target to start all settings from scratch each time
        # This is an easy way to reset all registered values
        RGen.app.reload_target!
        RGen.tester.generating = :program
        # Make the top level flow globally available, this helps to assign test descriptions
        # to the correct flow whenever tests are instantiated from sub-flows
        if RGen.interface_loaded? && RGen.interface.top_level_flow
          sub_flow = true
          if RGen.tester.doc?
            RGen.interface.flow.start_section
          end
        else
          sub_flow = false
        end
        job.output_file_body = options.delete(:name).to_s if options[:name]
        if sub_flow
          interface = RGen.interface
          opts = RGen.generator.option_pipeline.pop || {}
          interface.instance_exec(opts, &block)
          if RGen.tester.doc?
            RGen.interface.flow.stop_section
          end
          interface.close(flow: true, sub_flow: true)
        else
          RGen.log.info "Generating... #{RGen.file_handler.current_file.basename}"
          interface = RGen.reset_interface(options)
          RGen.interface.set_top_level_flow
          RGen.interface.flow_generator.set_flow_description(RGen.interface.consume_comments)
          interface.instance_eval(&block)
          interface.close(flow: true)
        end
      end

      def reset
        RGen.interface.clear_top_level_flow if RGen.interface_loaded?
      end

      def job
        RGen.app.current_job
      end
    end
  end
end
