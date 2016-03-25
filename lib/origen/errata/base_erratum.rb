module Origen
  module Errata
    class BaseErratum

      attr_accessor :id, :title, :description
      def initialize (id, title, description, options = {})
        @id = id
        @title = title
        @description = description
      end

    end
  end
end
