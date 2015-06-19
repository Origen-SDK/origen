module RGen
  module Tester
    module Generator
      class IdentityMap
        def initialize
          @store = {}
          @versions = {}
        end

        def current_version_of(obj)
          map = map_for(obj)
          if map
            map[:replaced_by] || map[:instance]
          else
            obj
          end
        end

        def map_for(obj)
          @store[obj.object_id]
        end
      end
    end
  end
end
