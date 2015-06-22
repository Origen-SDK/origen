module Origen
  module CodeGenerators
    class Bundler < Origen::CodeGenerators::Base
      desc <<-END
This generator will add the necessary files to convert the app to use bundler for gem
mangement (including Origen plugins).
END
      def create_gemspec_file
        if config[:type] == :application
          template 'templates/code_generators/gemfile_app.rb', File.join(Origen.root, 'Gemfile')
        else
          template 'templates/code_generators/gemfile_plugin.rb', File.join(Origen.root, 'Gemfile')
        end
      end
    end
  end
end
