module Origen
  class SiteConfig
    require 'pathname'
    require 'yaml'

    TRUE_VALUES = ['true', 'TRUE', '1', 1]
    FALSE_VALUES = ['false', 'FALSE', '0', 0]

    # Define a couple of site configs variables that need a bit of processing

    # Gets the gem_intall_dir. This is either site_config.home_dir/gems or the site configs gem_install_dir
    def gem_install_dir
      return "#{tool_repo_install_dir}/gems" if gems_use_tool_repo && tool_repo_install_dir && !user_install_enable
      dir = find_val('user_gem_dir')
      unless dir
        dir = "#{find_val('home_dir')}/gems"
      end
      dir
    end

    # Gets the user_install_dir. Like gem_install_dir, this default to somewhere home_dir, unless overridden
    def user_install_dir
      dir = find_val('user_install_dir')
      unless dir
        dir = find_val('home_dir')
      end
      dir
    end

    def method_missing(method, *args, &block)
      method = method.to_s
      if method =~ /(.*)!$/
        method = Regexp.last_match(1)
        must_be_present = true
      end
      val = find_val(method)
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

    def find_val(val, options = {})
      env = "ORIGEN_#{val.upcase}"
      if ENV.key?(env)
        config = ENV[env]
        if TRUE_VALUES.include?(val)
          config = true
        elsif FALSE_VALUES.include?(val)
          config = false
        end
        config
      else
        config = configs.find { |c| c.key?(val) }
        config ? config[val] : nil
      end
    end

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
          configs << YAML.load_file(file) if File.exist?(file) && YAML.load_file(file)
          file = File.join(path, 'origen_site_config.yml')
          configs << YAML.load_file(file) if File.exist?(file) && YAML.load_file(file)
          path = path.parent
        end
        # Add and any site_configs from the directory hierarchy where Ruby is installed
        path = Pathname.new($LOAD_PATH.last)
        until path.root?
          file = File.join(path, 'origen_site_config.yml')
          configs << YAML.load_file(file) if File.exist?(file) && YAML.load_file(file)
          path = path.parent
        end
        # Add the one from the Origen core as the lowest priority, this one defines
        # the default values
        configs << YAML.load_file(File.expand_path('../../../origen_site_config.yml', __FILE__))
        # Add the site_config from the user's home directory as highest priority, if it exists
        # But, make sure we take the site installation's setup into account.
        # That is, if user's home directories are somewhere else, make sure we use that directory to the find
        # the user's overwrite file. The user can then override that if they want."
        install_path = configs.find { |c| c.key?('home_dir') }
        install_path = install_path ? install_path['home_dir'] : nil
        install_path.nil? ? user_config = nil : user_config =  File.join(File.expand_path(install_path), 'origen_site_config.yml')
        if user_config && File.exist?(user_config)
          configs.unshift(YAML.load_file(user_config)) if YAML.load_file(user_config)
        end
        configs
      end
    end
  end

  def self.site_config
    @site_config ||= SiteConfig.new
  end
end
