module Origen
  module CodeGenerators
    class RSpec < Origen::CodeGenerators::Base
      desc <<-END
This generator will add the necessary files to use rspec for unit tests.
END
      def create_spec_helper_file
        template 'templates/code_generators/spec_helper.rb', File.join(Origen.root, 'spec', 'spec_helper.rb')
      end
    end
  end
end
