module Origen
  module Models
    class Mux
      include Origen::Model

      attr_reader :size
      attr_reader :select_lines

      def initialize(options = {})
        @input = []
        (2**select_lines).times do |i|
          @input << port("input#{i}".to_sym, size: size)
        end

        port :select, size: select_lines
        port :output, size: size

        output.connect_to do |i|
          unless ports[:select].data.undefined?
            send("input#{ports[:select].data}")[i].path
          end
        end
      end
    end
  end
end
