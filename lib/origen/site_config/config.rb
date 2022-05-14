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
            # Note the difference of time objects below will give the difference in seconds.
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
        def inform_user_of_cached_file
          if cached?
            puts yellow('Origen: Site Config: Found previously cached site config. Using the older site config.')
          else
            puts yellow('Origen: Site Config: No cached file found. An empty site config will be used in its place.')
          end
          puts
        end

        if centralized?
          puts "Pulling centralized site config from: #{path}"

          begin
            # TODO: needs to be replaced with a net/http equivalent, can't use gems here. The reference
            # to HTTParty will raise an error until that is done, but it will be handled gracefully below.
            text = HTTParty.get(path, verify: parent.find_val('centralized_site_config_verify_ssl'))
            puts "Caching centralized site config to: #{cached_file}"

            unless Dir.exist?(cached_file.dirname)
              FileUtils.mkdir_p(cached_file.dirname)
            end
            File.open(cached_file, 'w+') do |f|
              f.write(text)
            end
          rescue SocketError => e
            puts red("Origen: Site Config: Unable to connect to #{path}")
            puts red('Origen: Site Config: Failed to retrieve centralized site config!')
            puts red("Error from exception: #{e.message}")

            inform_user_of_cached_file
          rescue OpenSSL::SSL::SSLError => e
            puts red("Origen: Site Config: Unable to connect to #{path}")
            puts red('Origen: Site Config: Failed to retrieve centralized site config!')
            puts red("Error from exception: #{e.message}")
            puts red('It looks like the error is related to SSL certification. If this is a trusted server, you can use')
            puts red("the site config setting 'centralized_site_config_verify_ssl' to disable verifying the SSL certificate.")

            inform_user_of_cached_file
          rescue Exception => e
            # Rescue anything else to avoid any un-caught exceptions causing Origen not to boot.
            # Print lots of red so that the users are aware that there's a problem, but don't ultimately want this
            # to render Origen un-bootable
            puts red("Origen: Site Config: Unexpected exception ocurred trying to either retrieve or cache the site config at #{path}")
            puts red('Origen: Site Config: Failed to retrieve centralized site config!')
            puts red("Class of exception:   #{e.class}")
            puts red("Error from exception: #{e.message}")

            inform_user_of_cached_file
          end
          text
        end
      end
      alias_method :refresh, :fetch

      # Loads the site config into memory.
      # Process the site config as an ERB, if indicated to do so (.erb file extension)
      # After the initial load, any centralized site configs will be retreived (if needed), cached, and loaded.
      def load
        def read_erb(erb)
          ERB.new(File.read(erb), 0, '%<>')
        end

        if centralized?
          if !cached?
            if fetch
              erb = read_erb(cached_file)
            else
              # There was a problem fetching the config. Just use an empty string.
              # Warning message will come from #fetch
              erb = ERB.new('')
            end
          else
            erb = read_erb(cached_file)
          end

          @values = (YAML.load(erb.result) || {})
        else
          if File.extname(path) == '.erb'
            erb = read_erb(path)
            @values = (YAML.load(erb.result) || {})
          else
            @values = (YAML.load_file(path) || {})
          end
        end

        unless @values.is_a?(Hash)
          puts red("Origen: Site Config: The config at #{path} was not parsed as a Hash, but as a #{@values.class}")
          puts red('                     Please review the format of the this file.')
          puts red('                     Alternatively, an error condition may have been received from the server.')
          puts red("                     This site config is available at: #{cached_file}")
          puts red('                     This config will not be loaded and will be replaced with an empty config.')
          puts
          @values = {}
        end

        if centralized?
          # check for restricted centralized config values
          RESTRICTED_FROM_CENTRALIZED_VARIABLES.each do |var|
            if @values.key?(var)
              val = @values.delete(var)
              puts red("Origen: Site Config: config variable #{var} is not allowed in the centralized site config and will be removed.")
              puts red("                     Value #{val} will not be applied!")
            end
          end
        end

        @loaded = true
        @values
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

      private

      def red(message)
        "\e[0;31;49m#{message}\e[0m"
      end

      def yellow(message)
        "\e[0;33;49m#{message}\e[0m"
      end
    end
  end
end
