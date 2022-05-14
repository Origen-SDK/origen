module Origen
  module Features
    extend ActiveSupport::Concern

    autoload :Feature, 'origen/features/feature'

    module ClassMethods
      def features
        @features ||= {}
      end

      # Creates a Feature if it deos not already exists.
      # Returns the Feature object if it already exists.
      # Returns an array of features if no argument is provided.

      private

      def feature(name, options = {})
        name = name.to_s.downcase.to_sym
        if !features.key?(name)
          # Add the feature if it does not already exists

          # Read desciption from the caller if the description of feature
          # is not provided
          unless options.key?(:description)
            @file = define_file(caller[0])
            options[:description] = fetch_description(name)
          end
          features[name] = Feature.new(name, options)
        else # if feature with given name already exists
          fail "Feature #{name} already added!"
        end
      end

      def fetch_description(name)
        parse_description unless description_lookup[@file]
        begin
          desc = description_lookup[@file][name]
        rescue
          desc = []
        end
        desc
      end

      def define_file(file)
        if Origen.running_on_windows?
          fields = file.split(':')
          "#{fields[0]}:#{fields[1]}"
        else
          file.split(':').first

        end
      end

      def description_lookup
        @@description_lookup ||= {}
      end

      def parse_description
        desc = []
        File.readlines(@file).each do |line|
          if line =~ /^\s*#(.*)/
            desc << Regexp.last_match[1].strip
          elsif line =~ /(\s|:)feature(\s*)(=?>?)(\s?):(\w*)/
            description_lookup[@file] ||= {}
            description_lookup[@file][Regexp.last_match[5].to_sym] = desc
            desc = []
          else
            desc = []
          end
        end
      end
    end

    def has_features?(name = nil)
      if !name
        if feature.size == 0
          false
        else
          true
        end
      else
        feature.include?(name)
      end
    end
    alias_method :has_feature?, :has_features?

    # Returns an array of the names of all associated features
    def feature(name = nil)
      if !name
        self.class.features.keys
      else
        if self.class.features.key?(name)
          self.class.features[name]
        else
          fail "Feature #{name} does not exist!"
        end
      end
    end
    alias_method :features, :feature
  end
end
