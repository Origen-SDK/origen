module Origen
  module Models
    class Mux
      include Origen::Model
      attr_reader :number_of_options

      def initialize(options = {})
        port :select
        port :output
        @inputs = {}
        @input_ports = {}
        @number_of_options = 0

        output.connect_to do
          s = select.data
          if s == undefined
            undefined
          else
            option = @inputs.find do |v, connection|
              connection.data if s == v
            end
            option ? option[1] : undefined
          end
        end
      end

      def select_by(*nodes)
        select.connect_to(*nodes)
      end

      def option(val, *nodes)
        @number_of_options += 1
        @input_ix ||= -1
        @input_ix += 1
        p = add_port("input#{@input_ix}".to_sym)
        nodes.each do |node|
          p.connect_to node
        end
        [val].flatten.each do |val|
          if val.is_a?(Symbol)
            val = XNumber.new(val)
          end
          @inputs[val] = Ports::Connection.new(self, *nodes)
          @input_ports[val] = p
        end
      end

      def active_input
        s = select.data
        option = @input_ports.find do |v, port|
          s == v
        end
        option ? option[1] : nil
      end

      def select
        port[:select]
      end

      def default_connection
        output
      end
    end
  end
end
