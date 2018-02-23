require_relative './limit'
module Origen
  module Limits
    class LimitSet
      attr_accessor :id, :min, :typ, :max, :target, :description, :static, :owner, :type

      def initialize(id, owner, options)
        @id = id
        @description = options[:description]
        @owner = owner
        @min = Limit.new(options[:min], :min, @owner) unless options[:min].nil?
        @typ = Limit.new(options[:typ], :typ, @owner) unless options[:typ].nil?
        @max = Limit.new(options[:max], :max, @owner) unless options[:max].nil?
        @target = Limit.new(options[:target], :target, @owner) unless options[:target].nil?
        unless options[:static].nil?
          unless [true, false].include? options[:static]
            Origen.log.error("Static option must be set to 'true' or 'false'!")
            fail
          end
        end
        @static = options[:static].nil? ? false : options[:static]
        fail unless limits_ok?
      end

      # Common alias
      def name
        @id
      end

      def frozen?
        @static
      end

      def min=(val)
        if frozen?
          Origen.log.warn('Cannot change a frozen limit set!')
        else
          @min = Limit.new(val, :min, @owner)
        end
      end

      def max=(val)
        if frozen?
          Origen.log.warn('Cannot change a frozen limit set!')
        else
          @max = Limit.new(val, :max, @owner)
        end
      end

      def typ=(val)
        if frozen?
          Origen.log.warn('Cannot change a frozen limit set!')
        else
          @typ = Limit.new(val, :typ, @owner)
        end
      end

      def target=(val)
        if frozen?
          Origen.log.warn('Cannot change a frozen limit set!')
        else
          @target = Limit.new(val, :target, @owner)
        end
      end

      private

      # Check that min, max are not mixed with typ.  If a user wants
      # a baseline value for a spec use target as it will not be
      # checked against pass/fail
      def limits_ok?
        status = true
        # Must have at least one of the limit types defined
        if @min.nil? && @max.nil? && @typ.nil? && @target.nil?
          Origen.log.error("Limit set #{@id} does not have any limits defined!")
          return false
        end
        if @min.nil? ^ @max.nil?
          @type = :single_sided
          unless @typ.nil?
            status = false
            Origen.log.error "Limit set #{@id} has a typical limit defined with either min or max.  They are mutually exclusive, use 'target' when using min or max"
          end
          # Check if the target is OK
          unless @target.nil?
            if @min.nil?
              unless @target < @max
                status = false
                Origen.log.error("Limit set #{@id} has the target value #{@target} set greater than the max value #{@max}!")
              end
            else
              unless @target > @min
                status = false
                Origen.log.error("Limit set #{@id} has the target value #{@target} set less than the min value #{@min}!")
              end
            end
          end
        elsif @min.expr && @max.expr
          @type = :double_sided
          # Both min and max must be numerical to compare them
          if @min.value.is_a?(Numeric) && @max.value.is_a?(Numeric)
            # Check that min and max make sense
            if @max.value <= @min.value || @min.value >= @max.value
              status = false
              Origen.log.error "Limit set #{@id} has min (#{@min.value}) and max (#{@max.value}) reversed"
            end
            # Check that target is OK
            unless @target.nil?
              if @target.value <= @min.value || @target.value >= @max.value
                status = false
                Origen.log.error "Limit set #{@id} has a target (#{@target.value}) that is not within the min (#{@min.value}) and max #{@max.value}) values"
              end
            end
          end
        end
        status
      end
    end
  end
end
