module Origen
  module Specs
    # This class is used to store spec exhibit information used to document IP
    class Exhibit
      # ID for the exhibit.  This allows the exhibit to reference easier
      attr_accessor :id

      # Type of exhibit.  Currently only :fig is supported.  In the future, this could be :topic or :table or anything else
      attr_accessor :type

      # Title for the Exhibit.
      attr_accessor :title

      # Description for the Exhibit
      attr_accessor :description

      # Reference link
      attr_accessor :reference

      # Markup needed for the exhibit
      attr_accessor :markup

      # Do we include the exhibit in this block
      attr_accessor :include_exhibit

      # Block ID that this exhibit is being used in.
      attr_accessor :block_id

      # Title Override.  Allows for the SoC to override the title so that it makes more sense
      attr_accessor :title_override

      # Reference Override.  This allows for the SoC to use a different figure (e.g. Power Supplies are different)
      attr_accessor :reference_override

      # Description Override.  This allows for the SoC to use a different description
      attr_accessor :description_override

      def initialize(id, type, overrides, options = {})
        @id = id
        @type = type
        @title = options[:title]
        @description = options[:description]
        @reference = options[:reference]
        @title_override = overrides[:title]
        @reference_override = overrides[:reference]
        @description_override = overrides[:description]
        @markup = options[:markup]
        @include_exhibit = true
        @include_exhibit = options[:include_exhibit] unless options[:include_exhibit].nil?
        @block_id = options[:block_id]
      end
    end
  end
end
