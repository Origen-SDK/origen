module Origen
  module CommandHelpers
    def self.extend_options(opts, app_opts, options)
      app_opts.each do |app_option|
        if app_option.last.is_a?(Proc)
          ao_proc = app_option.pop
          if ao_proc.arity == 1
            opts.on(*app_option) { ao_proc.call(options) }
          else
            opts.on(*app_option) { |arg| ao_proc.call(options, arg) }
          end
        else
          opts.on(*app_option) {}
        end
      end
    end
  end
end
