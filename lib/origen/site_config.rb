module Origen
  class SiteConfig
    require 'pathname'
    require 'yaml'

    TRUE_VALUES = ['true', 'TRUE', '1', 1]
    FALSE_VALUES = ['false', 'FALSE', '0', 0]

    def method_missing(method, *args, &block)
      method = method.to_s
      if method =~ /(.*)!$/
        method = Regexp.last_match(1)
        must_be_present = true
      end
      env = "ORIGEN_#{method.upcase}"
      if ENV.key?(env)
        val = ENV[env]
        if TRUE_VALUES.include?(val)
          val = true
        elsif FALSE_VALUES.include?(val)
          val = false
        end
      else
        config = configs.find { |c| c.key?(method) }
        val = config ? config[method] : nil
      end
      if must_be_present && val.nil?
        puts "No value assigned for site_config attribute '#{method}'"
        puts
        fail 'Missing site_config value!'
      end
      define_singleton_method(method) do
        val
      end
      val
    end

    private

    def configs
      @configs ||= begin
        path = Pathname.pwd
        configs = []
        # Add any site_configs from where we are currently running from, i.e. the application
        # directory area
        until path.root?
          file = File.join(path, 'origen_site_config.yml')
          configs << YAML.load_file(file) if File.exist?(file)
          path = path.parent
        end
        # Add and any site_configs from the directory hierarchy where Ruby is installed
        path = Pathname.new($LOAD_PATH.last)
        until path.root?
          file = File.join(path, 'origen_site_config.yml')
          configs << YAML.load_file(file) if File.exist?(file)
          path = path.parent
        end
        # Add the one from the Origen core as the lowest priority, this one defines
        # the default values
        configs << YAML.load_file(File.expand_path('../../../origen_site_config.yml', __FILE__))
        configs
      end
    end
  end

  def self.site_config
    @site_config ||= SiteConfig.new
  end
end
