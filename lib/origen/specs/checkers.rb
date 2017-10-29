module Origen
  module Specs
    module Checkers
      require 'nokogiri'

      # rubocop:disable Style/RescueModifier:
      def name_audit(name)
        return name if name.nil?
        return nil unless name.is_a?(Symbol) || name.is_a?(String)
        if name == :inspect
          Origen.log.debug ':inspect is a reserved spec name'
          return nil
        end
        if name.match(/^\d/)
          Origen.log.debug "Spec #{name} starts with a number"
          return nil
        end
        if name.match(/\s+/)
          Origen.log.debug "Spec #{name} contains white space, removing it"
          name.delete!(/\s+/)
        end
        name.is_a?(String) ? name.downcase.to_sym : name
      end

      # Check that min, max are not mixed with typ.  If a user wants
      # a baseline value for a spec use target as it will not be
      # checked against pass/fail
      def limits_ok?
        status = true
        if (@min.exp.to_s.include? '/') || (@max.exp.to_s.include? '/')
          return status
        end
        if @min.exp.nil? ^ @max.exp.nil?
          @limit_type = :single_sided
          if @typ.exp
            # status = false
            Origen.log.debug "Spec #{@name} has a typical limit defined with either min or max.  They are mutually exclusive, use 'target' when using min or max"
          end
        elsif @min.exp && @max.exp
          @limit_type = :double_sided
          # Both min and max must be numerical to compare them
          if @min.value.is_a?(Numeric) && @max.value.is_a?(Numeric)
            # Check that min and max make sense
            if @max.value <= @min.value || @min.value >= @max.value
              status = false
              Origen.log.debug "Spec #{@name} has min (#{@min.value}) and max (#{@max.value}) reversed"
            end
            # Check that target is OK
            unless @target.nil?
              if @target.value <= @min.value || @target.value >= @max.value
                status = false
                Origen.log.debug "Spec #{@name} has a target (#{@target.value}) that is not within the min (#{@min.value}) and max #{@max.value}) values"
              end
            end
          end
        end
        status
      end

      def get_mode
        spec_mode = nil
        if current_mode.nil?
          if self == Origen.top_level
            spec_mode = :global
          else
            spec_mode = :local
          end
        else
          spec_mode = current_mode.name
        end
        spec_mode
      end

      def evaluate_limit(limit)
        return limit if [Fixnum, Float, Numeric].include? limit.class
        return nil if limit.nil?
        limit = limit.to_s if [Nokogiri::XML::NodeSet, Nokogiri::XML::Text, Nokogiri::XML::Element].include? limit.class
        if limit.is_a? Symbol
          limit = ':' + limit.to_s
        else
          limit.gsub!("\n", ' ')
          limit.scrub!
        end
        result = false
        if limit.match(/\:\S+/)
          limit_items = limit.split(/\:|\s+/).reject(&:empty?)
          references = limit.split(/\:|\s+/).select { |var| var.match(/^[a-zA-Z]\S+$/) }
          new_limit_items = [].tap do |limit_ary|
            limit_items.each do |item|
              if references.include? item
                # See if the limit is referencing a power domain, this should be extended to clocks
                # TODO: Expand limit references to check Origen::Clocks
                if Origen.top_level.respond_to? :power_domains
                  if Origen.top_level.power_domains.include? item.to_sym
                    limit_ary << Origen.top_level.power_domains(item.to_sym).nominal_voltage
                    next
                  end
                end
                if Origen.top_level.respond_to? :clocks
                  if Origen.top_level.clocks.include? item.to_sym
                    limit_ary << Origen.top_level.clocks(item.to_sym).freq_target
                    next
                  end
                end
                limit_ary << item
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
            return limit
          end
        elsif !!(limit.match(/^\d+\.\d+$/)) || !!(limit.match(/^-\d+\.\d+$/))
          result = Float(limit).round(4) rescue false # Use the same four digits of accuracy as the Spec model
        elsif !!(limit.match(/\d+\.\d+\s+\d+\.\d+/)) # workaround for multiple specs authoring bug
          Origen.log.debug "Found two numbers without an operator in the limit string '#{limit}', choosing the first..."
          first_number = limit.match(/(\d+\.\d+)\s+\d+\.\d+/).captures.first
          result = Float(first_number).round(4) rescue false # Use the same four digits of accuracy as the Spec model
        # elsif !!(limit.match(/^tbd$/i)) # unique case of TBD or To Be Determined, will convert to symbol
        #  limit = limit.downcase.to_sym
        else
          result = Integer(limit) rescue false
        end
        if result == false
          # Attempt to eval the limit because users could write a limit like "3.3 + 50.mV"
          # which would not work with the code above but should eval to a number 3.35
          begin
            result = eval(limit)
            return result.round(4) if result.is_a? Numeric
            rescue SyntaxError, NameError, TypeError
              Origen.log.debug "Limit '#{limit}' had to be rescued, storing it as a #{limit.class}"
              if limit.is_a? Symbol
                return limit
              else
                return "#{limit}"
              end
          end
        else
          return result
        end
      end
    end
  end
end
