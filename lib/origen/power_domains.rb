require_relative './power_domains/power_domain'
module Origen
  module PowerDomains
    def power_domains(expr = nil)
      if expr.nil?
        if @_power_domains.nil?
          @_power_domains = {}
        elsif @_power_domains.is_a? Hash
          if @_power_domains.empty?
            @_power_domains
          else
            @_power_domains.ids
          end
        else
          @_power_domains = {}
        end
      else
        @_power_domains.recursive_find_by_key(expr)
      end
    end

    def add_power_domain(id, options = {}, &block)
      @_power_domains ||= {}
      if @_power_domains.include?(id)
        Origen.log.error("Cannot create power domain '#{id}', it already exists!")
        fail
      end
      @_power_domains[id] = PowerDomain.new(id, options, &block)
    end
  end
end
