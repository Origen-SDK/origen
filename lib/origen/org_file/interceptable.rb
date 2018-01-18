module Origen
  class OrgFile
    module Interceptable
      extend ActiveSupport::Concern

      module ClassMethods
        def new(*args, &block)
          o = allocate
          i = OrgFile::Interceptor.new(o)
          o.__interceptor__ = i
          i.send(:initialize, *args, &block)
          i
        end
      end

      def myself
        @__interceptor__
      end

      # @api private
      def __interceptor__=(obj)
        @__interceptor__ = obj
      end
    end
  end
end
