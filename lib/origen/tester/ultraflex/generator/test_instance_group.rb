module Origen
  module Tester
    class Ultraflex
      module Generator
        class TestInstanceGroup
          attr_accessor :name, :version, :append_version

          include Enumerable

          def initialize(name, _options = {})
            @name = name
            @store = []
            @append_version = true
          end

          def name
            if unversioned_name
              if version && @append_version
                "#{unversioned_name}_v#{version}"
              else
                unversioned_name.to_s
              end
            end
          end

          def unversioned_name
            if @name
              if @name =~ /grp$/
                @name
              else
                "#{@name}_grp"
              end
            end
          end

          def <<(instance)
            @store << instance
          end

          def size
            @store.size
          end

          def each
            @store.each { |ins| yield ins }
          end

          def ==(other_instance_group)
            self.class == other_instance_group.class &&
              unversioned_name.to_s == other_instance_group.unversioned_name.to_s &&
              size == other_instance_group.size &&
              self.all? do |ins|
                other_instance_group.any? { |other_ins| ins == other_ins }
              end
          end
        end
      end
    end
  end
end
