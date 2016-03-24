module Origen
  module Errata
    class SwErratumWorkaround > BaseErratum

      def initialize(disposition, comment, patches)
        @disposition = disposition
        @comment = comment
        @patches = patches
      end
    end
  end
end
