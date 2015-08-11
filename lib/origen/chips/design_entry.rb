module Origen
  module Chips
    class Design_Entry
      # date that the document was released
      attr_accessor :date

      # document type, e.g. Reference Manual, One Pager, Data Sheet
      attr_accessor :type

      # revision
      attr_accessor :revision

      # nda
      attr_accessor :nda

      # released status
      attr_accessor :release

      # location
      attr_accessor :location

      # description of the item
      attr_accessor :description

      def initialize(date, type, revision, description, options = {})
        @date = date
        @type = type
        @revision = revision
        @description = description
        @nda = options[:nda]
        @release = options[:release]
        @location = options[:location]
      end
    end
  end
end
