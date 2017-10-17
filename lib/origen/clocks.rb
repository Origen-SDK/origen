require_relative './clocks/clock'
require_relative './clocks/clocks_collection'
module Origen
  module Clocks
    def clocks(expr = nil)
      @_clocks ||= ClocksCollection.new
      if expr.nil?
        @_clocks
      else
        @_clocks.recursive_find_by_key(expr)
      end
    end

    def add_clock(id, options = {}, &block)
      if clocks.include?(id)
        Origen.log.error("Cannot create clock '#{id}', it already exists!")
        fail
      end
      clocks[id] = Clock.new(id, self, options, &block)
    end
    alias_method :clock, :add_clock
  end
end
