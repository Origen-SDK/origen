module Origen
  module Models
    class Mux
      include Origen::Model

      def initialize(options = {})
        port :select
        port :output
        @inputs = {}

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
        [val].flatten.each do |val|
          if val.is_a?(Symbol)
            val = XNumber.new(val)
          end
          @inputs[val] = Ports::Connection.new(self, *nodes)
        end
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
