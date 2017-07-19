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
        # This global is set when Origen is first required, it generally means that what is considered
        # to be the pwd for the purposes of looking for a site_config file is the place from where the
        # user invoked Origen. Otherwise if the running app switches the PWD it can lead to confusing
        # behavior - this was a particular problem when testing the new app generator which switches the
        # pwd to /tmp to build the new app
        path = $_origen_invocation_pwd
        configs = []
        # Add any site_configs from where we are currently running from, i.e. the application
        # directory area
        until path.root?
          file = File.join(path, 'config', 'origen_site_config.yml')
          configs << YAML.load_file(file) if File.exist?(file)
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
        # Add the site_config from the user's home directory as highest priority, if it exists
        # But, make sure we take the site installation's setup into account.
        # That is, if user's home directories are somewhere else, make sure we use that directory to the find
        # the user's overwrite file. The user can then override that if they want."
        install_path = configs.find { |c| c.key?('origen_install_dir') }
        install_path = install_path ? install_path['origen_install_dir'] : nil
        user_config = File.join(File.expand_path(install_path), 'origen_site_config.yml')
        if File.exist?(user_config)
          configs.unshift(YAML.load_file(user_config))
        end
        configs
      end
    end
  end

  def self.site_config
    @site_config ||= SiteConfig.new
  end
end
