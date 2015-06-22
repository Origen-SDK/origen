module Origen
  module Specs
    # This class is used to store spec exhibit information used to document IP
    class Version_History
      attr_accessor :date, :author, :changes

      def initialize(date, author, changes)
        @date = date
        @author = author
        @changes = changes
      end
    end
  end
end
