require_relative './limits/limit'
require_relative './limits/limit_set'
module Origen
  module Limits
    TYPES = [:min, :typ, :max, :target]

    def add_limits(set, options)
      @_limits ||= {}
      options.ids.each do |limit_type|
        unless TYPES.include? limit_type
          Origen.log.error("Limit type '#{limit_type}' not supported, choose from #{TYPES}!")
          fail
        end
      end
      if @_limits.include? set
        # Limit set already exists, modify it unless it is frozen
        unless @_limits[set].frozen?
          options.each do |limit_type, limit_expr|
            @_limits[set].send("#{limit_type}=", limit_expr)
          end
        end
      else
        # Create a default limit set
        @_limits[set] = LimitSet.new(set, self, options)
      end
    end

    def limits(set = nil)
      @_limits ||= {}
      if set.nil?
        @_limits
      else
        @_limits[set]
      end
    end
  end
end
