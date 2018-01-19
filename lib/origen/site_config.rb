module Origen
  class SiteConfig
    require 'pathname'
    require 'yaml'
    require 'etc'

    TRUE_VALUES = ['true', 'TRUE', '1', 1]
    FALSE_VALUES = ['false', 'FALSE', '0', 0]

    # Define a couple of site configs variables that need a bit of processing

    # Gets the gem_intall_dir. This is either site_config.home_dir/gems or the site configs gem_install_dir
    def gem_install_dir
      if gems_use_tool_repo && tool_repo_install_dir && !user_install_enable
        path = eval_path(tool_repo_install_dir)
      else
        path = eval_path(find_val('user_gem_dir') || find_val('gem_install_dir') || home_dir)
      end

      append = find_val('append_gems')
      append = 'gems' if append == true || append.nil?

      if append
        unless path.end_with?(append)
          path = File.join(path, append)
        end
      end
      path
    end
    alias_method :user_gem_dir, :gem_install_dir

    # Gets the user_install_dir. Like gem_install_dir, this default to somewhere home_dir, unless overridden
    def user_install_dir
      eval_path(find_val('user_install_dir') || home_dir)
    end

    def home_dir
      eval_path(find_val('home_dir') || '~/')
    end

    def eval_path(path, options = {})
      # Expand the first path. This will take care of replacing any leading ~/ with the home directory.
      if path.start_with?('\\')
        path[0] = ''
      else
        path = File.expand_path(path)
      end

      # Gsub the remaining ~ that aren't escaped.
      # If it was escaped, eat the escape character
      path.gsub!(/(?<!\\|\A)~/, "#{Etc.getlogin}")
      path.gsub!(/\\(?=~)/, '')

      append = find_val('append_dot_origen')
      append = '.origen' if append == true || append.nil?

      if append
        unless path.end_with?(append)
          path = File.join(path, append)
        end
      end
      path
    end

    # Dynamically remove the highest instance of :var
    def remove_highest(var)
      @configs.each do |c|
        if c.key?(var)
          return c.delete(var)
        end
      end

      # return nil if we haven't returned a value yet
      nil
    end

    # Dynamically remove all the instances of :var
    def remove_all_instances(var)
      # Iterate though all the site configs, removing every instance of :var
      # Return an array containing the value of :var at each config,
      # from lowest priority to highest.
      # If [] is returned, it implies that there was no instancs of :var to be removed.
      ret = []
      @configs.each do |c|
        if c.key?(var)
          ret << c.delete(var)
        end
      end
      ret
    end
    alias_method :purge, :remove_all_instances

    # Dynamically add a new site variable at the highest priority.
    def add_as_highest(var, value)
      # Don't want to override anything, so just shift in a dummy site config instance at the highest level and
      # set the value there.
      configs.prepend(var.to_s => value)
    end
    alias_method :[]=, :add_as_highest

    # Dynamically add a new site variable at the lowest priority.
    # Essentially, this sets a new default value.
    def add_as_lowest(var, value)
      # Don't want to override anything, so just shift in a dummy site config at the lowest level and
      # set the value there.
      configs.append(var.to_s => value)
    end

    # Adds a new site config file as the highest priority
    def add_site_config_as_highest(site_config_file)
      configs.prepend YAML.load_file(File.expand_path('../../../origen_site_config.yml', __FILE__))
    end

    # Adds a new site config file as the highest priority
    def add_site_config_as_lowest(site_config_file)
      configs.append YAML.load_file(File.expand_path('../../../origen_site_config.yml', __FILE__))
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
        find_val(method)
      end
      val
    end

    def get(val)
      find_val(val)
    end
    alias_method :[], :get

    def get_all(val)
      ret = []
      @configs.each do |c|
        if c.key?(val)
          ret << c[val]
        end
      end
      ret
    end

    def clear
      @configs.clear
    end

    def rebuild!
      configs!
    end

    private

    def find_val(val, options = {})
      env = "ORIGEN_#{val.upcase}"
      if ENV.key?(env)
        value = ENV[env]
        value
      else
        config = configs.find { |c| c.key?(val) }
        value = config ? config[val] : nil
      end

      if TRUE_VALUES.include?(value)
        return true
      elsif FALSE_VALUES.include?(value)
        return false
      end
      value
    end

    def configs
      @configs ||= configs!
    end

    # Forces a reparse of the site configs.
    # This will set the @configs along the current path first,
    # then, using those values, will add a site config at the home directory.
    def configs!
      @configs = begin
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
        configs
      end
      
      # Add the site_config from the user's home directory as highest priority, if it exists
      # But, make sure we take the site installation's setup into account.
      # That is, if user's home directories are somewhere else, make sure we use that directory to the find
      # the user's overwrite file. The user can then override that if they want."
      user_config = File.join(File.expand_path(user_install_dir), 'origen_site_config.yml')
      if File.exist?(user_config)
        @configs.unshift(YAML.load_file(user_config)) if YAML.load_file(user_config)
      end
      
      @configs
    end
  end

  def self.site_config
    @site_config ||= SiteConfig.new
  end
end
