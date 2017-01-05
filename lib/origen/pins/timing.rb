module Origen
  module Pins
    # Top-level manager for the devices pin timing setups,
    # an instance of this class is automatically instantiated
    # and available as dut.timing
    module Timing
      autoload :Timeset,     'origen/pins/timing/timeset'
      autoload :Wave,        'origen/pins/timing/wave'

      # Add a very basic timeset where all pins will have default waves,
      # which will drive for the whole cycle and compare at 50% of the
      # current period
      #
      #   add_timeset :func
      def add_timeset(*args, &block)
        if block_given?
          timesets(*args, &block)
        else
          timesets(args.first) { }
        end
      end

      def timesets(name=nil, options={})
        name, options = nil, name if name.is_a?(Hash)
        @timesets ||= {}.with_indifferent_access
        # If defining a new timeset
        if block_given?
          @timesets[name] ||= Timeset.new(name)
          yield @timesets[name]
        else
          if name
            @timesets[name]
          else
            @timesets
          end
        end
      end

      # Returns the currently selected timeset, or nil
      def current_timeset(*args, &block)
        if block_given?
          timesets(*args, &block)
        else
          if args.first
            timesets(args.first)
          else
            @current_timeset
          end
        end
      end
      alias :timeset :current_timeset

      # Set the current timeset, this will be called automatically
      # if the timeset is changed via tester.set_timeset
      def current_timeset=(id)
        if timesets[id]
          @current_timeset = id
        else
          fail "Timeset #{id} has not been defined!"
        end
      end
      alias :timeset= :current_timeset=
    end
  end
end
