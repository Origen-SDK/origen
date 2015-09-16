module Origen
  module Specs
    # This class is used to store spec note information used to document IP
    class Note
      # id is the id for the note.  The goal for the id is to allow multiple specs to reference one note.
      # spec.notes = [id1, id2, id3]
      # spec1.notes = [id1, id4, id5]
      attr_accessor :id

      # Type should be :ac or :dc, but this might have been phased out.
      #  TODO:  Check to see if :type has been deprecated or is still needed
      attr_accessor :type

      # Mode will match the mode that this note belongs to.
      #  TODO:  Check to see if :mode has been deprecated or is still needed
      attr_accessor :mode

      # Audience should be :ac or :dc, but this might have been phased out.
      #  TODO:  Check to see if :type has been deprecated or is still needed
      attr_accessor :audience

      # Plain text of the note.  No Mark-up allowed in this field.
      attr_accessor :text

      # Markup of the text field.  Currently markup has been tested with
      #
      # * DITA
      # * XML
      # * HTML
      #
      # Need to test the following markup
      #
      # * Markdown
      attr_accessor :markup

      # Internal comment that could be used to know why the note was needed. Think of this as a breadcrumb
      # to find out about more information on the note.
      attr_accessor :internal_comment

      # Initialize the class
      def initialize(id, type, options = {})
        @id = id
        @type = type
        @mode = options[:mode]
        @audience = options[:audience]
        @text = options[:text]
        @markup = options[:markup]
        @internal_comment = options[:internal_comment]
      end
    end
  end
end
