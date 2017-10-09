require 'colorize'
require_relative './power_domains/power_domain'
require_relative './power_domains/power_domains_collection'
module Origen
  module PowerDomains
    def power_domains(expr = nil)
      if expr.nil?
        if @_power_domains.nil?
          @_power_domains = PowerDomainsCollection.new
        elsif @_power_domains.is_a? PowerDomainsCollection
          @_power_domains
        else
          @_power_domains = PowerDomainsCollection.new
        end
      else
        @_power_domains.recursive_find_by_key(expr)
      end
    end

    def add_power_domain(id, options = {}, &block)
      @_power_domains ||= PowerDomainsCollection.new
      if @_power_domains.include?(id)
        Origen.log.error("Cannot create power domain '#{id}', it already exists!")
        fail
      end
      @_power_domains[id] = PowerDomain.new(id, options, &block)
    end
  end
end
