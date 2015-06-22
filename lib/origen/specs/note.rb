module Origen
  module Specs
    # This class is used to store spec note information used to document IP
    class Note
      attr_accessor :id, :type, :mode, :audience, :text, :markup

      def initialize(id, type, options = {})
        @id = id
        @type = type
        @mode = options[:mode]
        @audience = options[:audience]
        @text = options[:text]
        @markup = options[:markup]
      end
    end
  end
end
