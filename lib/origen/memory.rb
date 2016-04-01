module Origen
  module Memory
    def memory(address, options = {})
      if is_top_level?
        r = "mem_#{address.to_s(16)}".to_sym
        unless has_reg?(r)
          if memory_address_aligned?(address)
            add_reg r, address, size: memory_width
          end
        end
        send(r)
      else
        Origen.top_level.memory(address + base_address, options)
      end
    end
    alias_method :mem, :memory

    def memory_address_aligned?(address)
      b = (memory_width / 8) - 1
      unless address & b == 0
        s = b - 1
        aligned = (address >> s) << s
        fail "Address #{address.to_hex} is not aligned to the memory width, it should be #{aligned.to_hex}"
      end
      true
    end

    def memory_width
      if is_top_level?
        @memory_width ||= 32
      else
        Origen.top_level.memory_width
      end
    end

    def memory_width=(size)
      if is_top_level?
        unless size % 8 == 0
          fail 'Memory width must be a multiple of 8'
        end
        if @memory_width
          fail 'The memory width cannot be changed after a memory location has been referenced'
        end
        @memory_width = size
      else
        Origen.top_level.memory_width = size
      end
    end
  end
end
