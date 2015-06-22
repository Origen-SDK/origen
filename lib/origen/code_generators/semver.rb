module Origen
  module CodeGenerators
    class Semver < Origen::CodeGenerators::Base
      desc <<-END
This generator will convert an application to use semantic (1.2.3) style versioning.
It can also be used to bring a legacy version file up to date with the latest structure.
END
      def create_version_file
        if config[:change]
          @version = config[:change]
        else
          @version = Origen.app.version
          # Ensure > 0.0.0 due to Bundler issues resolving 0.0.0.preX versions
          until @version.semantic? && @version.greater_than_or_equal_to?(VersionString.new('0.0.1'))
            ver = ask 'What version do you want to start from (this must be > 0.0.0) ? [0.1.0]'
            if !ver || ver.empty?
              @version = VersionString.new('0.1.0')
            else
              @version = VersionString.new(ver)
            end
          end
        end
        template 'templates/code_generators/version.rb', File.join(Origen.root, 'config', 'version.rb'), force: true
      end

      def set_configuration
        unless Origen.app.config.semantically_version
          comment_config :semantically_version
          add_config :semantically_version, true
        end
      end

      def print_version
        puts
        puts "You're new app version is: #{Origen.app.version(refresh: true)}"
      end
    end
  end
end
