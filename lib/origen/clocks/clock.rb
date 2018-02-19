module Origen
  module Clocks
    class Clock
      attr_accessor :id, :owner, :users, :freq_target, :freq_range, :setpoint, :instantiate_users

      def initialize(id, owner, options = {}, &block)
        @id = id
        @owner = owner
        @id = @id.symbolize unless id.is_a? Symbol
        @instantiate_users = true
        options.each { |k, v| instance_variable_set("@#{k}", v) }
        (block.arity < 1 ? (instance_eval(&block)) : block.call(self)) if block_given?
        @users = [@users] unless @users.is_a? Array
        add_users_sub_blocks if @instantiate_users
        @setpoint = @freq_target
      end

      def name
        @id
      end

      # Returns an Array of IPs that use a clock
      def users
        @users
      end

      def setpoint=(val)
        if val == :gated || val == 'gated'
          @setpoint = :gated
        else
          setpoint_ok?(val) # This just warns if the clock is set out of range
          @setpoint = val
        end
      end

      def setpoint_ok?(val = nil)
        val = @setpoint if val.nil?
        if @freq_range == :fixed
          if val == @freq_target
            return true
          else
            Origen.log.warn("Clock '#{id}' is a fixed clock with a target frequency of #{@freq_target.as_Hz}")
            return false
          end
        else
          if @freq_range.include?(val)
            return true
          else
            Origen.log.warn("Setpoint (#{setpoint_string(val)}) for clock '#{id}' is not within the frequency range (#{freq_range_string})")
            return false
          end
        end
      end
      alias_method :value_ok?, :setpoint_ok?
      alias_method :val_ok?, :setpoint_ok?

      # Set the clock to the target frequency
      def setpoint_to_target
        @setpoint = @freq_target
      end

      # Current setpoint, defaults top nil on init
      def setpoint
        @setpoint
      end
      alias_method :curr_value, :setpoint
      alias_method :value, :setpoint

      # Acceptable frequency range
      def freq_range
        @freq_range
      end
      alias_method :range, :freq_range

      # Acceptable frequency range
      def freq_target
        @freq_target
      end
      alias_method :target, :freq_target

      # Check if the clock users are defined anywhere in the DUT
      def users_defined?
        undefined_ips = ips - Origen.all_sub_blocks
        if undefined_ips.empty?
          return true
        else
          Origen.log.warn("Clock '#{id}' has the following IP undefined: #{undefined_ips}")
          return false
        end
      end

      def method_missing(m, *args, &block)
        ivar = "@#{m.to_s.gsub('=', '')}"
        ivar_sym = ":#{ivar}"
        if m.to_s =~ /=$/
          define_singleton_method(m) do |val|
            instance_variable_set(ivar, val)
          end
        elsif instance_variables.include? ivar_sym
          instance_variable_get(ivar)
        else
          define_singleton_method(m) do
            instance_variable_get(ivar)
          end
        end
        send(m, *args, &block)
      end

      private

      # Instantiate and IP/users that use/access the clock
      def add_users_sub_blocks
        @users.each do |ip|
          if @owner.respond_to? ip
            next
          else
            @owner.sub_block ip
          end
        end
      end

      # Ensure attributes are the correct type
      def attrs_ok?
        return_value = true
        unless description.is_a? String
          Origen.log.error("Clock attribute 'description' must be a String!")
          return_value = false
        end
        return_value = false unless frequencies_ok?
        return_value
      end

      def frequencies_ok?
        if @freq_target.nil?
          false
        elsif @freq_range.nil?
          Origen.log.error("Missing frequency range for clock '#{name}'!")
          false
        elsif freq_range.is_a? Range
          if freq_range.include?(@freq_target)
            true
          else
            Origen.log.error("PPEKit: Frequency target #{@freq_target} is not inbetween the frequency range #{freq_range} for clock '#{name}'!")
            false
          end
        else
          Origen.log.error("Clock attribute 'freq_range' must be a Range!")
          return_value = false
        end
      end

      def setpoint_string(val = nil)
        if val.nil?
          @setpoint.as_Hz unless @setpoint.nil?
        else
          val.as_Hz
        end
      end

      def freq_range_string
        start_freq = @freq_range.first
        end_freq = @freq_range.last
        "#{start_freq.as_Hz}\.\.#{end_freq.as_Hz}"
      end

      def clock_freqs_ok?
        if @freq_target.nil?
          false
        elsif @freq_range == :fixed
          true
        else
          if @freq_range.nil?
            Origen.log.error("PPEKit: Missing frequency target or range for clock '#{id}'!")
            false
          elsif @freq_range.include?(@freq_target)
            true
          else
            Origen.log.error("PPEKit: Frequency target #{@freq_target} is not inbetween the freq range #{@freq_range} for clock '#{id}'!")
            false
          end
        end
      end
    end
  end
end
