module Origen
  module CodeGenerators
    class GemSetup < Origen::CodeGenerators::Base
      desc <<-END
This generator creates a gemspec file in the top-level directory to allow it
to be packed up and distributed as a gem.
END
      def create_gemspec_file
        @summary = ask 'Describe your plugin in a few words:'
        template 'templates/code_generators/gemspec.rb', File.join(Origen.root, "#{Origen.app.name}.gemspec")
      end

      def create_master_require_file
        file = "#{Origen.root}/lib/#{Origen.app.name}.rb"
        if File.exist?(file)
          prepend_to_file file, <<-END
require "origen"
require_relative "../config/application.rb"
require_relative "../config/environment.rb"

END
        else
          create_file file do
            <<-END
require "origen"
require_relative "../config/application.rb"
require_relative "../config/environment.rb"
END
          end
        end
      end

      def verify_semver
        unless Origen.app.version.semantic?
          puts <<-END

Warning, you application is not currently using semantic (1.2.3) versioning, this must be used if
you want to publish your plugin as a gem.

To upgrade your application to semantic versioning run the following command:

  origen add semver

END
        end
      end
    end
  end
end
