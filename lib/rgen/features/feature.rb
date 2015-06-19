module RGen
  module Features
    class Feature
      attr_reader :name
      attr_reader :description

      def initialize(name, options = {})
        @name = name
        @description = options[:description]
      end

      def describe
        return 'No description provided!' if @description == []
        if @description.class == Array
          @description.join(' ')
        else
          @description
        end
      end
    end
  end
end
