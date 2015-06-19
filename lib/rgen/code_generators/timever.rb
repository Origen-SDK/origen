module RGen
  module CodeGenerators
    class Timever < RGen::CodeGenerators::Base
      desc <<-END
This generator will convert an application to use timestamp (sm_2014_12_04_11_11) versioning.
It can also be used to bring a legacy version file up to date with the latest structure.
END
      def create_version_file
        if config[:change]
          @version = config[:change]
        else
          @version = RGen.app.version
          unless @version.timestamp?
            if @version.production?
              @version = VersionString.production_timestamp
            else
              @version = VersionString.development_timestamp
            end
          end
        end
        template 'templates/code_generators/version_time.rb', File.join(RGen.root, 'config', 'version.rb'), force: true
      end

      def set_configuration
        if RGen.app.config.semantically_version
          comment_config :semantically_version
          add_config :semantically_version, false
        end
      end

      def print_version
        puts
        puts "You're new app version is: #{RGen.app.version(refresh: true)}"
      end
    end
  end
end
