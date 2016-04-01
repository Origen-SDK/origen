module Origen
  module Ports
    autoload :Port,     'origen/ports/port'
    autoload :Section,  'origen/ports/section'
    autoload :BitCollection,  'origen/ports/bit_collection'
    autoload :PortCollection,  'origen/ports/port_collection'

    def add_port(name, options = {})
      p = Port.new(self, name, options)
      if block_given?
        p.send(:defining) do
          yield p
        end
      end
      _ports.add(name.to_s.symbolize, p)
      p
    end

    def port(*args, &block)
      if block_given?
        add_port(*args, &block)
      else
        if args.first
          if has_port?(args.first)
            _ports[args.first.to_s.symbolize]
          else
            if _initialized?
              puts "Model #{self.class} does not have a port named #{args.first}, the available ports are:"
              puts _ports.keys
              puts
              fail 'Missing port error'
            else
              # Assume this is a pin definition while the model is still initializing
              add_port(*args)
            end
          end
        else
          _ports
        end
      end
    end
    alias_method :ports, :port

    def has_port?(name)
      _ports.key?(name.to_s.symbolize)
    end

    def method_missing(method, *args, &block)
      if _ports.key?(method.to_s.symbolize)
        _ports[method.to_s.symbolize]
      else
        super
      end
    end

    def respond_to?(sym)
      has_port?(sym) || super(sym)
    end

    private

    def _ports
      @_ports ||= PortCollection.new
    end
  end
end
