module Origen
  module Ports
    autoload :Port,     'origen/ports/port'
    autoload :Section,  'origen/ports/section'

    def add_port(name, options = {})
      p = Port.new(self, name, options)
      if block_given?
        p.send(:defining) do
          yield p
        end
      end
      _ports[name] = p
      p
    end

    def port(*args, &block)
      if block_given?
        add_port(*args, &block)
      else
        if args.first
          if has_port?(args.first)
            _ports[args.first]
          else
            if initialized?
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
      _ports.key?(name)
    end

    def method_missing(method, *args, &block)
      if _ports.key?(method)
        _ports[method]
      else
        super
      end
    end

    def respond_to?(sym)
      _ports.key?(sym) || super(sym)
    end

    private

    def _ports
      @_ports ||= {}.with_indifferent_access
    end
  end
end
