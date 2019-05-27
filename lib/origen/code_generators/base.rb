require 'thor/group'
module Origen
  module CodeGenerators
    class Error < Thor::Error # :nodoc:
    end

    class Base < Thor::Group
      include Thor::Actions
      include Origen::CodeGenerators::Actions

      add_runtime_options!
      strict_args_position!

      # Convenience method to get the top-level namespace from the class name.
      # It is returned as a lower cased and underscored string.
      def self.namespace(name = nil)
        @namespace ||= begin
          names = super.split(':')
          if names.size == 1
            nil
          else
            names.first.sub(/^r_gen/, 'origen')
          end
        end
      end

      # Sets the base_name taking into account the current class namespace.
      def self.name
        @name ||= begin
          name = to_s.split('::').last.sub(/(CodeGenerator|Generator)$/, '').underscore
          if name == 'klass'
            'class'
          elsif name == 'mod'
            'module'
          else
            name
          end
        end
      end

      # Cache source root and add lib/generators/base/generator/templates to
      # source paths.
      def self.inherited(base) #:nodoc:
        super
        if base.name && base.name !~ /Base$/
          if base.namespace == 'origen'
            Origen::CodeGenerators.origen_generators[base.name] = base
          else
            Origen::CodeGenerators.plugin_generators[base.namespace] ||= {}
            Origen::CodeGenerators.plugin_generators[base.namespace][base.name] = base
          end
        end
        # Give all generators access to Origen core files in their source path,
        # with their own app as highest priority
        base.source_paths << Origen.root if Origen.app_loaded?
        base.source_paths << Origen.top
      end

      def self.banner
        "origen new #{namespace == 'origen' ? '' : namespace + ':'}#{name} [options]"
      end
    end
  end
end
