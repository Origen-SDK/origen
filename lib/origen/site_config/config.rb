module Origen
  class SiteConfig
    class Config
      attr_reader :path
      attr_reader :parent
      attr_reader :type
      attr_reader :values
      
      RESTRICTED_FROM_CENTRALIZED_VARIABLES = [
        'centralized_site_config',
        'centralized_site_config_cache_dir',
        'centralized_site_config_verify_ssl',
      ]
      
      def initialize(path:, parent:, values: nil)
        @parent = parent
        if path == :runtime
          path = "runtime_#{self.object_id}"
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
          self.load
        end
      end
      
      def needs_refresh?
        if centralized?
          if refresh_time < 0
            false
          elsif cached?
            # If the refresh time is 0, this will always be true
            (Time.now - cached_file.ctime)/3600.0 > refresh_time
          else
            # If the cached file cannot be found, force a new fetch
            true
          end
        else
          false
        end
      end
      
      def refresh_time
        self.parent.find_val('centralized_site_config_refresh')
      end
            
      def cached_file
        @cached_file ||= Pathname(parent.centralized_site_config_cache_dir).join('cached_config')
      end
      
      def cached?
        File.exists?(cached_file)
      end
      
      def fetch
        if centralized?
          puts "Pulling centralized site config from: #{path}"
          text = HTTParty.get(path, verify: parent.find_val('centralized_site_config_verify_ssl'))
          
          puts "Caching centralized site config to: #{cached_file}"
          unless Dir.exists?(cached_file.dirname)
            FileUtils.mkdir_p(cached_file.dirname)
          end
          File.open(cached_file, 'w').write(text)
          text
        else
          nil
        end
      end
      alias_method :refresh, :fetch
      
      # Loads the site config into memory.
      # Process the site config as an ERB, if indicated to do so (.erb file extension)
      # After the initial load, any centralized site configs will be retreived (if needed), cached, and loaded.
      def load
        if centralized?
          unless cached?
            fetch
          end
          erb = ERB.new(File.read(cached_file))
          @values = (YAML.load(erb.result) || {})
          
          # check for restricted centralized config values
          RESTRICTED_FROM_CENTRALIZED_VARIABLES.each do |var|
            if @values.key?(var)
              val = @values.delete(var)
              Origen.log.error "Origen: Site Config: " + 
                               "config variable #{var} is not allowed in the centralized site config and will be removed. " +
                               "Value #{val} will not be applied!"
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
