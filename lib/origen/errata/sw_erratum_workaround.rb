module Origen
  module Errata
    class SwErratumWorkaround < BaseErratum
  
      attr_accessor :disposition, :comment, :patches
      def initialize(id, title, description, sw_disposition, comment, patches)
        super(id, title, description)
        @sw_disposition = sw_disposition
        @comment = comment
        @patches = patches
      end
    end
  end
end
