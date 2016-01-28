module Origen
  module Specs
    # This class is used to store spec exhibit information used to document IP
    class Exhibit
      attr_accessor :id, :type, :title, :description, :reference, :markup, :include_exhibit, :block_id

      def initialize(id, type, options = {})
        @id = id
        @type = type
        @title = options[:title]
        @description = options[:description]
        @reference = options[:reference]
        @markup = options[:markup]
        @include_exhibit = true
        @include_exhibit = options[:include_exhibit] unless options[:include_exhibit].nil?
        @block_id = options[:block_id]
      end
    end
  end
end
