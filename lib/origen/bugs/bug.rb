module Origen
  module Bugs
    class Bug
      attr_reader :affected_versions

      attr_reader :name
      alias_method :id, :name

      def initialize(name, options = {})
        @name = name
        @affected_versions = [options[:affected_version] || options[:affected_versions]].flatten.compact
        @fixed_on_version = options[:fixed_on_version]
      end

      def present_on_version?(version, _options = {})
        if affected_versions.empty?
          if fixed_on_version
            version < fixed_on_version
          else
            true
          end
        else
          affected_versions.include?(version)
        end
      end

      def fixed_on_version
        @fixed_on_version || begin
          unless affected_versions.empty?
            affected_versions.max + 1
          end
        end
      end
    end
  end
end
