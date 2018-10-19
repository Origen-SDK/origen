module Origen
  class SiteConfig
    class Config
      attr_reader :path
      attr_reader :parent
      attr_reader :type
      attr_reader :values

      RESTRICTED_FROM_CENTRALIZED_VARIABLES = %w(centralized_site_config centralized_site_config_cache_dir centralized_site_config_verify_ssl)

      def initialize(path:, parent:, values: nil)
        @parent = parent
        if path == :runtime
          path = "runtime_#{object_id}"
          @type = :runtime
        elsif path.start_with?('http')
          @path = path
          @type = :centralized
        else
          @path = path
          @type = :local
        end
        @contains_centralized = false
        @loaded = false

        if values
          @values = values
          @loaded = true
        else
          @values = nil
          load
        end
      end

      def needs_refresh?
        if centralized?
          if refresh_time < 0
            false
          elsif cached?
            # If the refresh time is 0, this will always be true
            (Time.now - cached_file.ctime) / 3600.0 > refresh_time
          else
            # If the cached file cannot be found, force a new fetch
            true
          end
        else
          false
        end
      end

      def refresh_time
        parent.find_val('centralized_site_config_refresh')
      end

      def cached_file
        @cached_file ||= Pathname(parent.centralized_site_config_cache_dir).join('cached_config')
      end

      def cached?
        File.exist?(cached_file)
      end

      def fetch
        if centralized?
          puts "Pulling centralized site config from: #{path}"

          begin
            text = HTTParty.get(path, verify: parent.find_val('centralized_site_config_verify_ssl'))
            puts "Caching centralized site config to: #{cached_file}"

            unless Dir.exist?(cached_file.dirname)
              FileUtils.mkdir_p(cached_file.dirname)
            end
            File.open(cached_file, 'w').write(text)

          rescue SocketError => e
            puts "Origen: Site Config: Unable to connect to #{path}".red
            puts 'Origen: Site Config: Failed to retrieve centralized site config!'.red
            puts "Error from exception: #{e.message}".red

            if cached?
              puts 'Origen: Site Config: Found previously cached site config. Using the older site config.'.red
            else
              puts 'Origen: Site Config: No cached file found. An empty site config will be used in its place.'.red
            end
            puts
          rescue OpenSSL::SSL::SSLError => e
            puts "Origen: Site Config: Unable to connect to #{path}".red
            puts 'Origen: Site Config: Failed to retrieve centralized site config!'.red
            puts "Error from exception: #{e.message}".red
            puts 'It looks like the error is related to SSL certification. If this is a trusted server, you can use ' \
                 "the site config setting 'centralized_site_config_verify_ssl' to disable verifying the SSL certificate.".red

            if cached?
              puts 'Origen: Site Config: Found previously cached site config. Using the older site config.'.red
            else
              puts 'Origen: Site Config: No cached file found. An empty site config will be used in its place.'.red
            end
            puts
          end
          text
        end
      end
      alias_method :refresh, :fetch

      # Loads the site config into memory.
      # Process the site config as an ERB, if indicated to do so (.erb file extension)
      # After the initial load, any centralized site configs will be retreived (if needed), cached, and loaded.
      def load
        if centralized?
          if !cached?
            if fetch
              erb = ERB.new(File.read(cached_file))
            else
              # There was a problem fetching the cnofig. Just use an empty string.
              # Warning message will come from #fetch
              erb = ERB.new('')
            end
          else
            erb = ERB.new(File.read(cached_file))
          end

          @values = (YAML.load(erb.result) || {})

          # check for restricted centralized config values
          RESTRICTED_FROM_CENTRALIZED_VARIABLES.each do |var|
            if @values.key?(var)
              val = @values.delete(var)
              puts 'Origen: Site Config: ' \
                               "config variable #{var} is not allowed in the centralized site config and will be removed. " \
                               "Value #{val} will not be applied!".red
            end
          end

          @loaded = true
          @values
        else
          if File.extname(path) == '.erb'
            erb = ERB.new(File.read(path))
            @values = (YAML.load(erb.result) || {})
          else
            @values = (YAML.load_file(path) || {})
          end
          @loaded = true
          @values
        end
      end

      def remove_var(var)
        @values.delete(var)
      end

      def has_var?(var)
        @values.key?(var)
      end

      # Finds the value from this config, or from one of its centralized configs (if applicable)
      def find_val(val)
        @values[val]
      end
      alias_method :[], :find_val

      def loaded?
        @loaded
      end

      def local?
        type == :local
      end

      def centralized?
        type == :centralized
      end

      def runtime?
        type == :runtime
      end
    end
  end
end
