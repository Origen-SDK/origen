module Origen
  module Specs
    # This class is used to store spec exhibit information used to document IP
    class Version_History
      attr_accessor :label, :date, :author, :changes, :external_changes_internal

      def initialize(date, author, changes, label = nil, external_changes_internal = nil)
        @date = date
        @author = author
        @changes = changes
        @label = label
        @external_changes_internal = external_changes_internal
      end
    end # class Version History
  end # module Specs
end # module Origen
