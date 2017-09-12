module Origen
  module Tests
    class Test
      attr_accessor :id, :owner, :description, :conditions, :platforms

      def initialize(id, &block)
        @id = id
        @description = ''
        @conditions, @platforms = [], []
        @id = @id.symbolize unless @id.is_a? Symbol
        (block.arity < 1 ? (instance_eval(&block)) : block.call(self)) if block_given?
        fail unless attrs_ok?
      end

      def name
        @id
      end

      def method_missing(m, *args, &block)
        ivar = "@#{m.to_s.gsub('=', '')}"
        ivar_sym = ":#{ivar}"
        if m.to_s =~ /=$/
          define_singleton_method(m) do |val|
            instance_variable_set(ivar, val)
          end
        elsif instance_variables.include? ivar_sym
          instance_variable_get(ivar)
        else
          define_singleton_method(m) do
            instance_variable_get(ivar)
          end
        end
        send(m, *args, &block)
      end

      private

      def attrs_ok?
        return_value = true
        [:conditions, :platforms].each do |attr|
          unless instance_variable_get("@#{attr}").is_a? Array
            Origen.log.error("Test attribute '#{attr}' should be an Array!")
            return_value = false
          end
        end
        unless @description.is_a? String
          Origen.log.error("Test attribute 'description' must be a String!")
          return_value = false
        end
        return_value
      end
    end
  end
end
