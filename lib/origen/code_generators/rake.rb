module Origen
  module CodeGenerators
    class Rake < Origen::CodeGenerators::Base
      desc <<-END
This generator will add the necessary files to convert the app to use rake for general
build commands.
END
      def create_rake_file
        template 'templates/code_generators/rakefile.rb', File.join(Origen.root, 'Rakefile')
      end
    end
  end
end
