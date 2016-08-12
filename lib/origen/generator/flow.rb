module Origen
  class Generator
    class Flow
      attr_accessor :top_level

      def create(options = {}, &block)
        # Refresh the target to start all settings from scratch each time
        # This is an easy way to reset all registered values
        Origen.app.reload_target!
        Origen.tester.generating = :program
        # Make the top level flow globally available, this helps to assign test descriptions
        # to the correct flow whenever tests are instantiated from sub-flows
        if Origen.interface_loaded? && Origen.interface.top_level_flow
          sub_flow = true
          if Origen.tester.doc?
            Origen.interface.flow.start_section
          end
        else
          sub_flow = false
        end
        job.output_file_body = options.delete(:name).to_s if options[:name]
        if sub_flow
          interface = Origen.interface
          opts = Origen.generator.option_pipeline.pop || {}
          Origen.interface.startup(options) if Origen.interface.respond_to?(:startup)
          interface.instance_exec(opts, &block)
          Origen.interface.shutdown(options) if Origen.interface.respond_to?(:shutdown)
          if Origen.tester.doc?
            Origen.interface.flow.stop_section
          end
          interface.close(flow: true, sub_flow: true)
        else
          Origen.log.info "Generating... #{Origen.file_handler.current_file.basename}"
          interface = Origen.reset_interface(options)
          Origen.interface.set_top_level_flow
          Origen.interface.flow_generator.set_flow_description(Origen.interface.consume_comments)
          options[:top_level] = true
          Origen.interface.startup(options) if Origen.interface.respond_to?(:startup)
          interface.instance_eval(&block)
          Origen.interface.shutdown(options) if Origen.interface.respond_to?(:shutdown)
          interface.at_flow_end if interface.respond_to?(:at_flow_end)
          interface.close(flow: true)
        end
      end

      def reset
        Origen.interface.clear_top_level_flow if Origen.interface_loaded?
      end

      def job
        Origen.app.current_job
      end
    end
  end
end
