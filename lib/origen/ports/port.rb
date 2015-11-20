module Origen
  module Ports
    class Port
      attr_reader :size
      attr_reader :parent
      attr_reader :id
      attr_reader :type

      alias_method :name, :id
      alias_method :owner, :parent

      def self.connections
        @connections ||= {}
      end

      def initialize(parent, id, options = {})
        @size = options[:size]
        @parent = parent
        @id = id
        @type = options[:type]
        @bit_names = {}.with_indifferent_access
        @connections = []
      end

      def port
        self
      end

      def connect_to(*nodes, &block)
        options = nodes.last.is_a?(Hash) ? nodes.pop : {}
        if block_given?
          if nodes.empty?
            c = Connection.new(self, block, called_by: caller[0])
          else
            fail 'When supplying a block to connect_to, no other nodes can be given'
          end
        else
          c = Connection.new(self, *nodes, called_by: caller[0])
          # Store a centralized reference to this new connection, for each path or object
          # it references
          cs = Port.connections[top_level] ||= {}
          nodes.each do |n|
            if n.is_a?(String)
              if n =~ /(.*)\[\d+:?\d*\]/
                cs[Regexp.last_match(1)] = c
              else
                cs[n] = c
              end
            elsif n.is_a?(Ports::Section)
              cs[n.port] = c
            elsif n.is_a?(Ports::Port)
              cs[n] = c
            end
          end
        end
        connections << c
      end
      alias_method :connect, :connect_to

      def inspect
        "<#{self.class}:#{object_id} id:#{id} path:#{path}>"
      end

      def connections
        unless @referenced_connections_done
          if cs = Port.connections[top_level]
            if cs[self]
              @connections << cs[self].from_pov(self)
            end
            if cs[path]
              @connections << cs[path].from_pov(self)
            end
            @bit_names.each do |n|
              if con = cs["#{path}.#{n}"]
                @connections << con.from_pov(self)
              end
            end
          end
          @referenced_connections_done = true
        end
        @connections
      end

      def data(options = {})
        # Always return a drive value regardless of contention with other values, this would normally
        # only be used on top-level ports anyway, but being able to absolutely force an internal
        # node is useful for debug
        return @drive_value if @drive_value
        if options[:exclude]
          options[:exclude] << self
        else
          options[:exclude] = [self]
        end
        if connections.empty?
          undefined
        else
          datas = connections.map { |c| c.data(options) }
          datas.reduce(:|)
        end
      end

      def describe(options = {})
        desc = ['********************']
        desc << "Port id:   #{id}"
        desc << "Port path: #{path}"
        desc << ''
        desc << 'Connections'
        desc << '-----------'
        desc << ''
        table = netlist.table
        ((size - 1)..0).to_a.each do |i|
          if table[path]
            c = [table[path]['*'], table[path][i]].flatten.compact.map { |n| n.is_a?(Proc) ? 'Proc' : n }
            desc << "#{i} - #{c.shift}"
            c.each do |n|
              desc << "     - #{n}"
            end
          else
            desc << "#{i} - none"
          end
        end
        desc << ''

        if options[:return]
          desc
        else
          puts desc.join("\n")
        end
      end

      def path
        if parent.path.empty?
          id.to_s
        else
          "#{parent.path}.#{id}"
        end
      end

      def bits(index, name, options = {})
        if @defining
          @bit_names[name] = index
        else
          fail 'Cannot add additional port bits once the port definition is complete'
        end
      end

      def drive(value = nil, options = {})
        value, options = nil, value if value.is_a?(Hash)
        @drive_value = value
      end

      def [](val)
        Section.new(self, val)
      end

      def to_bc
        to_section.to_bc
      end

      def method_missing(method, *args, &block)
        if @bit_names[method]
          s = self[@bit_names[method]]
          define_singleton_method "#{method}" do
            s
          end
          send(method)
        else
          super
        end
      end

      def respond_to?(sym)
        super || @bit_names[sym]
      end

      def top_level
        parent.local_top_level
      end

      private

      def defining
        @defining = true
        yield
        @defining = false
      end
    end
  end
end
