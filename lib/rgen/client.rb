module RGen
  # Client for communicating with the RGen server
  class Client
    # This is based on the example here:
    #   https://github.com/jnunemaker/httparty/tree/v0.9.0

    require 'json'
    require 'httparty'
    include HTTParty

    USE_DEV_SERVER = false
    DEV_PORT = 3000

    def post(path, options = {})
      options[:port] = port
      self.class.post("#{url}/#{path}", options)
    end

    def get(path, options = {})
      self.class.get("#{url}/#{path}", options)
    end

    def url
      "http://rgen-hub.am.freescale.net:#{port}/api"
    end

    def port
      USE_DEV_SERVER ? DEV_PORT : 80
    end

    def record_invocation(command)
      data = {
        user:         RGen.current_user.core_id,
        application:  RGen.app.config.initials,
        app_version:  RGen.app.version,
        rgen_version: RGen.version,
        command:      command,
        platform:     RGen.running_on_windows? ? 'windows' : 'linux'
      }
      post('record_invocation', body: data)
    end

    # Returns an array of data packets for all plugins
    def plugins
      return @plugins if @plugins
      response = get('plugins')
      @plugins = JSON.parse(response.body, symbolize_names: true)[:plugins]
    end

    def plugin(name)
      response = get("plugins/#{name}")
      JSON.parse(response.body, symbolize_names: true)[:plugin]
    end

    # Returns a data packet for RGen core
    def rgen
      @rgen ||= begin
        response = get('plugins/rgen_core')
        JSON.parse(response.body, symbolize_names: true)[:plugin]
      end
    end
    alias_method :rgen_core, :rgen

    # This will be called by the RGen release process to post
    # the latest app version information to the server
    def release!
      version = RGen.app.version
      body = { version: version.to_s }
      if version.production?
        body[:type] = :production
      else
        body[:type] = :development
      end
      post("plugins/#{RGen.app.name}/release", body: body)
    end

    # Returns the latest production RGen version
    def latest_production
      RGen::VersionString.new(rgen[:latest_version_prod])
    end

    # Returns the latest developmen RGen version
    def latest_development
      RGen::VersionString.new(rgen[:latest_version_dev])
    end
  end
end
