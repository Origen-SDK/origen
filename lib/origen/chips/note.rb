module Origen
  module Chips
    # This class is used to store spec note information used to document IP
    class RSS_Note
      attr_accessor :id, :type, :feature

      def initialize(id, type, feature)
        @id = id
        @type = type
        @feature = feature
      end
    end
  end
end
