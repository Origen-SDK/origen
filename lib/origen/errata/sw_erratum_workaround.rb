module Origen
  module Errata
    class SwErratumWorkaround
  
      attr_accessor :id, :title, :description, :sw_disposition, :comment, :patches
      def initialize(id, options = {})
	@id = id
	@title = options[:title]
	@description = options[:description]
        @sw_disposition = options[:sw_disposition]
        @comment = options[:comment]
        @patches = options[:patches]
      end
    end
  end
end
