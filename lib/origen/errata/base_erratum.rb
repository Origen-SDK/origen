module Origen
  module Errata
    class BaseErratum

      attr_accessor :id, :type, :title, :description
      def initialize (id, type, options = {})#title, description, options = {})
        @id = id
        @type = type
        @title = options[:title]
        @description = options[:description]
      end

    end
  end
end
