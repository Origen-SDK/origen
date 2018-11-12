module Origen
  module RevisionControl
    class Perforce < Base
      def initialize(options = {})
        super
        begin
          require 'origen_perforce'
        rescue LoadError
          puts 'To use the Perforce revision control system with Origen, you must add the following gem to your Gemfile:'
          puts
          puts "  gem 'origen_perforce'"
          puts
          exit 1
        end
        _initialize_(options)
      end
    end
  end
end
