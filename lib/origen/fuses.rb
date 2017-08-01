require_relative 'fuses/fuse_field'
module Origen
  module Fuses
    def fuses
      @fuses ||= {}
    end

    def fuse_field(name, start_addr, size, options = {})
      if fuses.respond_to? :name
        Origen.log.error("Cannot create fuse field '#{name}', it already exists!")
        fail
      end
      fuses[name] = FuseField.new(name, start_addr, size, self, options)
    end
  end
end
