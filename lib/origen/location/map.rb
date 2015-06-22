require 'active_support/concern'
module Origen
  module Location
    module Map
      extend ActiveSupport::Concern

      module ClassMethods
        def define_locations(defaults = {})
          @x = @x ? (@x + 1) : 0  # Provides a unique ID for each define_locations block
          default_attributes[@x] = defaults
          @defining = true
          yield
          @defining = false
        end

        def constructor(&block)
          if defining?
            constructors[@x] = block
          else
            constructors[:default] = block
          end
        end

        def default_constructor(attributes, defaults)
          Origen::Location::Base.new(defaults.merge(attributes))
        end

        def definitions
          @definitions ||= {}
        end

        def constructors
          @constructors ||= {}
        end

        def default_attributes
          @default_attributes ||= {}
        end

        def defining?
          @defining
        end

        # A hash of constructed location objects, i.e. an entry will be cached here the first time a location
        # is referenced outside of its initial definition, after that it will be served directly from here.
        def constructed
          @constructed ||= {}
        end

        # Provides accessors for all named locations, for example:
        #
        #   $dut.nvm.fmu.ifr_map.probe1_pass
        def method_missing(method, *args, &block)
          if defining?
            if definitions[method]
              warning "Redefinition of map location: #{method}"
            end
            definitions[method] = { attributes: args.first, x: @x }
          else
            super
          end
        end
      end

      def method_missing(method, *args, &block)
        klass = self.class
        klass.constructed[method] || begin
          definition = klass.definitions[method]
          if definition
            defaults = klass.default_attributes[definition[:x]] || {}
            constructor = klass.constructors[definition[:x]] || klass.constructors[:default]
            if constructor
              instance = constructor.call(definition[:attributes], defaults)
            else
              instance = klass.default_constructor(definition[:attributes], defaults)
            end
            klass.constructed[method] = instance
          end
        end || super
      end
    end
  end
end
