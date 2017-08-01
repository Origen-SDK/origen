module Origen
  module Fuses
    # Currently just a simple data container most suited for import from Excel/CSV/XML
    # by stuffing all attributes into the options hash
    class FuseField
      attr_accessor :name, :size, :start_addr, :owner

      def initialize(name, start_addr, size, owner, options = {})
        options = {
          default_value: 0
        }.merge(options)
        @name, @start_addr, @size, @owner = name, start_addr, size, owner
        # Check if the start address is in Verilog
        if @start_addr.is_a? String
          @start_addr = @start_addr.verilog_to_i if @start_addr.is_verilog_number?
        end
        unless @size.is_a?(Numeric) && @start_addr.size.is_a?(Numeric)
          Origen.log.error("Fuse fields must have numeric attributes for 'size' and 'start_addr'!")
          fail
        end
        # If the fuse field is owned by Top Level DUT then keep the start address as-is
        # If not, then add the fuse field start address to the base address of the IP
        unless owner.is_top_level?
          @start_addr += owner.base_address if owner.respond_to?(:base_address)
        end
        options.each do |o, val|
          instance_eval("def #{o};@#{o};end") # getter
          instance_eval("def #{o}=(val);@#{o}=val;end") # setter
          ivar_name = "@#{o}".to_sym
          instance_variable_set(ivar_name, options[o])
        end

        def reprogrammeable?
          self.respond_to?(:reprogrammeable) ? reprogrammeable : true
        end

        def customer_visible?
          self.respond_to?(:customer_visible) ? customer_visible : false
        end
      end
    end
  end
end
