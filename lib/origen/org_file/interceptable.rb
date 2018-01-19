module Origen
  class OrgFile
    module Interceptable
      def self.included(base)
        base.extend ClassMethods

        # Defers this executing until the whole class has loaded
        Origen.after_app_loaded do
          unless (base.instance_methods - Object.methods).include?(:global_path_to)
            puts 'When adding the OrgFile::Interceptable module to a class, the class must define an instance method called "global_path_to", like this:'
            puts
            puts '  # Must return a string that contains a global path to access the given object,'
            puts '  # here for example if the object was a pin'
            puts '  def global_path_to'
            puts '    "dut.pins(:#{id})"'
            puts '  end'
            fail "Incomplete integration of OrgFile::Interceptable in #{base}"
          end
        end
      end

      module ClassMethods
        def new(*args, &block)
          o = allocate
          i = OrgFile::Interceptor.new(o)
          o.__interceptor__ = i
          i.send(:initialize, *args, &block)
          i
        end
      end

      # Class which include OrgFile::Interceptor should use 'myself' anytime then want to reference 'self',
      # this ensures that there are never any references to the unwrapped object
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
