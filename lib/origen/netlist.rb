module Origen
  module Netlist
    autoload :List,        'origen/netlist/list'
    autoload :Connectable, 'origen/netlist/connectable'

    def netlist
      @netlist ||= if netlist_top_level == self
          List.new(self)
        else
          netlist_top_level.netlist
        end

    end

    def netlist_top_level
      @netlist_top_level ||= begin
        p = self
        p = p.parent while p.respond_to?(:parent) && p.parent
        p
      end
    end
  end
end
