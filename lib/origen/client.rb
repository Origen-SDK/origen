module Origen
  # Client for communicating with the Origen server
  class Client
    # This is based on the example here:
    #   https://github.com/jnunemaker/httparty/tree/v0.9.0

    require 'json'
    require 'net/http'
    # include HTTParty

    USE_DEV_SERVER = false
    DEV_PORT = 3000

    def post(path, options = {})
      options[:port] = port
      invocation_url = URI.parse("#{url}/#{path}")
      http = Net::HTTP.new(invocation_url.host, invocation_url.port)
      http.post(invocation_url, JSON.dump(options[:body]), 'Content-type' => 'application/vnd.api+json', 'Accept' => 'text/json, application/vnd.api+json')
    end

    def get(path, options = {})
      self.class.get("#{url}/#{path}", options)
    end

    def url
      if Origen.site_config.invocation_url.nil?
        'http://localhost:3000'
      else
        Origen.site_config.invocation_url
      end
    end

    def port
      USE_DEV_SERVER ? DEV_PORT : 80
    end

    def record_invocation(command)
      content = {
        data: {
          type: 'applications',
          attributes: {
            user: Origen.current_user.core_id,
            application: Origen.app.config.initials,
            "app-version": Origen.app.version,
            "origen-version": Origen.version,
            command: command,
            platform: Origen.running_on_windows? ? 'windows' : 'linux'
          }
        }
      }
      post('applications', body: content)
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

    # Returns a data packet for Origen core
    def origen
      @origen ||= begin
        response = get('plugins/origen_core')
        JSON.parse(response.body, symbolize_names: true)[:plugin]
      end
    end
    alias_method :origen_core, :origen

    # This will be called by the Origen release process to post
    # the latest app version information to the server
    def release!
      version = Origen.app.version
      body = { version: version.to_s }
      if version.production?
        body[:type] = :production
      else
        body[:type] = :development
      end
      post("plugins/#{Origen.app.name}/release", body: body)
    end

    # Returns the latest production Origen version
    def latest_production
      Origen::VersionString.new(origen[:latest_version_prod])
    end

    # Returns the latest developmen Origen version
    def latest_development
      Origen::VersionString.new(origen[:latest_version_dev])
    end
  end
end
