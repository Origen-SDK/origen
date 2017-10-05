require_relative './power_supplies/power_supply'
module Origen
  module PowerSupplies
    def power_supplies(expr = nil)
      if expr.nil?
        if @_power_supplies.nil?
          @_power_supplies = {}
        elsif @_power_supplies.is_a? Hash
          if @_power_supplies.empty?
            @_power_supplies
          else
            @_power_supplies.ids
          end
        else
          @_power_supplies = {}
        end
      else
        @_power_supplies.recursive_find_by_key(expr)
      end
    end
    alias_method :supplies, :power_supplies

    def add_power_supply(id, options = {}, &block)
      @_power_supplies ||= {}
      if @_power_supplies.include?(id)
        Origen.log.error("Cannot create power supply '#{id}', it already exists!")
        fail
      end
      @_power_supplies[id] = PowerSupply.new(id, options, &block)
    end
    alias_method :add_supply, :add_power_supply
  end
end
