require_relative 'fuses/fuse_field'
module Origen
  module Fuses
    def fuses(expr = nil)
      if expr.nil?
        if @_fuses.nil?
          @_fuses = {}
        elsif @_fuses.is_a? Hash
          if @_fuses.empty?
            @_fuses
          else
            @_fuses.ids
          end
        else
          @_fuses = {}
        end
      else
        @_fuses.recursive_find_by_key(expr)
      end
    end

    def fuse_field(name, start_addr, size, options = {})
      @_fuses ||= {}
      if fuses.respond_to? :name
        Origen.log.error("Cannot create fuse field '#{name}', it already exists!")
        fail
      end
      @_fuses[name] = FuseField.new(name, start_addr, size, self, options)
    end
  end
end
