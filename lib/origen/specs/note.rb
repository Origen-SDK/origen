module Origen
  module Specs
    # This class is used to store spec note information used to document IP
    class Note
      attr_accessor :id, :type, :mode, :audience, :text, :markup, :internal_comment

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
