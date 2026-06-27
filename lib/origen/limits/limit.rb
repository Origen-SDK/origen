module Origen
  module Limits
    class Limit
      attr_accessor :expr, :owner, :type
      attr_writer :value

      def initialize(expr, type, owner, options = {})
        @expr = expr
        @owner = owner
        @type = type
        @value = evaluate_expr
      end

      # If the value is still a String then it could be
      # due to referencing another LimitSet that is
      # yet to be defined
      def value
        if @value.is_a?(String)
          evaluate_expr
        else
          @value
        end
      end

      # Backwards compatibility
      def exp
        @expr
      end

      private

      def fetch_reference_value(ref)
        ref = ref.to_sym unless ref.is_a?(Symbol)
        # Check if the reference is to another limit set
        if owner.limits.include? ref
          return owner.limits(ref).send(type).value
          # Check if the reference is to a power domain
        end

        if Origen.top_level.respond_to? :power_domains
          if Origen.top_level.power_domains.include? ref
            # Need to check the limit type and retrieve the appropriate value
            case @type.to_s
            when /target|typ/
              return Origen.top_level.power_domains(ref).nominal_voltage
            else
              return Origen.top_level.power_domains(ref).send(@type)
            end
          end
        end
        # Check if the reference is to a clock
        if Origen.top_level.respond_to? :clocks
          if Origen.top_level.clocks.include? ref
            # Need to check the limit type and retrieve the appropriate value
            case @type.to_s
            when /target|typ/
              Origen.top_level.clocks(ref).freq_target
            else
              Origen.top_level.clocks(ref).send(@type)
            end
          end
        end
      end

      def evaluate_expr
        return @expr if @expr.is_a?(Numeric)
        return nil if @expr.nil?

        if @expr.is_a? Symbol
          @expr = ':' + @expr.to_s
        else
          @expr.gsub!("\n", ' ')
          @expr.scrub!
        end
        result = false
        if @expr.match(/\:\S+/)
          limit_items = @expr.split(/\:|\s+/).reject(&:empty?)
          if limit_items.size == 1
            return fetch_reference_value(limit_items.first)
          else
            references = @expr.split(/\:|\s+/).select { |var| var.match(/^[a-zA-Z]\S+$/) }
            new_limit_items = [].tap do |limit_ary|
              limit_items.each do |item|
                if references.include? item
                  limit_ary << fetch_reference_value(item)
                  next
                else
                  limit_ary << item
                end
              end
            end
            new_limit = new_limit_items.join(' ')
            new_limit_references = new_limit.split(/\:|\s+/).select { |var| var.match(/^[a-zA-Z]\S+$/) }
            if new_limit_references.empty?
              result = eval(new_limit).round(4)
            else
              return @expr
            end
          end
        elsif !!(@expr.match(/^\d+\.\d+$/)) || !!(@expr.match(/^-\d+\.\d+$/))
          result = Float(@expr).round(4) rescue false # rubocop:disable Style/RescueModifier
        elsif !!(@expr.match(/\d+\.\d+\s+\d+\.\d+/))
          Origen.log.debug "Found two numbers without an operator in the @expr string '#{@expr}', choosing the first..."
          first_number = @expr.match(/(\d+\.\d+)\s+\d+\.\d+/).captures.first
          result = Float(first_number).round(4) rescue false # rubocop:disable Style/RescueModifier
        else
          result = Integer(@expr) rescue false # rubocop:disable Style/RescueModifier
        end
        if result == false
          # Attempt to eval the @expr because users could write a @expr like "3.3 + 50.mV"
          # which would not work with the code above but should eval to a number 3.35
          begin
            result = eval(@expr)
            result.round(4) if result.is_a? Numeric
          rescue ::SyntaxError, ::NameError, ::TypeError
            Origen.log.debug "Limit '#{@expr}' had to be rescued, storing it as a #{@expr.class}"
            if @expr.is_a? Symbol
              @expr
            else
              "#{@expr}"
            end
          end
        else
          result
        end
      end
    end
  end
end
