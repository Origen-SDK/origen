module Origen
  module Parameters
    require 'delegate'
    class Live < ::Delegator
      def initialize(options)
        @owner = options[:owner]
        @path = options[:path].split('.')
        @name = options[:name]
      end

      def __getobj__
        p = @owner.params
        @path.each { |pt| p = p.send(pt) }
        p.send(@name)
      end

      def is_a_live_parameter?
        true
      end
    end
  end
end
