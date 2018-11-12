require_relative './power_domains/power_domain'
require_relative './power_domains/power_domains_collection'
module Origen
  module PowerDomains
    def power_domains(expr = nil)
      @_power_domains ||= PowerDomainsCollection.new
      if expr.nil?
        @_power_domains
      else
        @_power_domains.recursive_find_by_key(expr)
      end
    end

    def add_power_domain(id, options = {}, &block)
      if power_domains.include?(id)
        Origen.log.error("Cannot create power domain '#{id}', it already exists!")
        fail
      end
      power_domains[id] = PowerDomain.new(id, options, &block)
    end
    alias_method :power_domain, :add_power_domain
  end
end
