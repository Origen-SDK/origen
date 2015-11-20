module Origen
  module Ports
    class Connection
      attr_reader :port
      attr_reader :nodes
      alias_method :parent, :port

      def initialize(port, *nodes)
        options = nodes.last.is_a?(Hash) ? nodes.pop : {}
        @port = port
        @called_by = options[:called_by]
        # Store these in reverse order so that the first item in a
        # multi-node connection refers to position 0
        @nodes = nodes.reverse!
        @unsized_items = 0
        @declared_size = 0
      end

      def data(options = {})
        d = 0
        p = 0
        cleaned_nodes.each do |n|
          if n[:data]
            data = n[:data]
          elsif n[:proc]
            data = n[:proc].call
            data = data.data if data.respond_to?(:data)
          else
            if n[:obj].is_a?(Ports::Port) || n[:obj].is_a?(Ports::Section)
              port = n[:obj].port
              if (options[:exclude] || []).include?(port)
                data = 0
              else
                data = n[:obj].data(options)
              end
            else
              data = n[:obj].data
            end
          end
          # Undefined states are not properly modelled right now, treat them as 0's
          # in port connections for simplicity
          data = 0 if data == undefined
          d |= (data << p)
          if cleaned_nodes.size > 1
            p += n[:size] || missing_size
          end
        end
        d
      end

      def from_pov(port)
        cleaned_nodes.each do |n|
          if n[:obj] == port || (n[:obj].is_a?(Ports::Section) && n[:obj].port == port)
            return Connection.new(port, self.port)
          end
        end
        fail 'Unresolved port view'
      end

      private

      def missing_size
        if port.size
          port.size - @declared_size
        else
          error 'When a connection contains an unsized item, the size of the port must be declared'
        end
      end

      def top_level
        @top_level ||= port.parent.local_top_level
      end

      def cleaned_nodes
        @cleaned_nodes ||= nodes.map { |node| clean(node) }
        if @unsized_items > 1
          error 'Only 1 item in a port connection can be unsized'
        end
        @cleaned_nodes
      end

      def clean(node)
        if node.is_a?(Origen::Ports::Section)
          @declared_size += node.size
          { size: node.size,
            obj:  node
          }

        elsif node.is_a?(Origen::Ports::Port)
          if node.size
            @declared_size += node.size
          else
            @unsized_items += 1
          end
          { size: node.size,
            obj:  node
          }

        elsif node.is_a?(Origen::Registers::BitCollection) ||
              node.is_a?(Origen::Registers::Reg) || node.is_a?(Origen::Registers::Bit)
          @declared_size += node.size
          { size: node.size,
            obj:  node
          }

        elsif node.is_a?(Symbol)
          n = SizedNumber.new(node)
          @declared_size += n.size
          { size: n.size,
            data: n
          }

        elsif node.is_a?(SizedNumber)
          @declared_size += node.size
          { size: node.size,
            data: node
          }

        elsif node.is_a?(Numeric)
          @unsized_items += 1
          { data: node }

        elsif node.is_a?(Proc)
          { proc: node }

        else
          error "Don't know how to process a node of class #{node.class} in a port connection"
        end
      end

      def error(msg)
        puts msg
        puts
        puts @called_by if @called_by
        fail
      end
    end
  end
end
