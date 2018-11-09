module Origen
  class SiteConfig
    require 'pathname'
    require 'yaml'
    require 'etc'
    require 'erb'
    require 'colored'
    require 'httparty'
    require_relative 'site_config/config'

    # require this version of Origen
    #require_relative '../origen'

    TRUE_VALUES = ['true', 'TRUE', '1', 1]
    FALSE_VALUES = ['false', 'FALSE', '0', 0]

    # Adding parameters to this array will prevent them from being converted to booleans if
    # they are assigned one of the values in the TRUE_VALUES/FALSE_VALUES arrays
    NON_BOOLEAN_PARAMETERS = [:lsf_cores, :centralized_site_config_refresh]

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
      # Any leading ~ should be expanded with whatever ~/ points to. This needs to be done now because later ~ will be replaced with just the username.
      path = path.sub(/^~/, File.expand_path('~/'))

      # Gsub the remaining ~ that aren't escaped.
      # If it was escaped, eat the escape character
      path.gsub!(/(?<!\\|\A)~/, "#{Etc.getlogin}")
      path.gsub!(/\\(?=~)/, '')

      # Now, expand the entire path for any other OS-specific symbols.
      # One note, if we still have a leading '~', that means it was escaped at the beginning. So, what we'll do for this is let it expand
      # then replace the leading File.expand_path('~/') with just '~', pretty much the opposite of path.sub(/^~/, File.expand_path('~/'))
      # Note, we can't just take it out, expand, then add it back  because expanding the path on Windows will expand to
      # C:\, or D:\ or whatever, so need to do this 'expand, then unexpand' method.
      if path.start_with?('~')
        path = File.expand_path(path).sub(/^#{Regexp.quote(File.expand_path('~/'))}/, '~')
      else
        path = File.expand_path(path)
      end

      append = find_val('append_dot_origen')
      append = '.origen' if append == true || append.nil?

      gem_append = find_val('append_gems')
      gem_append = 'gems' if gem_append == true || gem_append.nil?

      if append
        unless path.end_with?(append) || (path.end_with?(File.join(append, gem_append)) if gem_append)
          path = File.join(path, append)
        end
      end
      path
    end

    def centralized_site_config_cache_dir
      File.expand_path(find_val('centralized_site_config_cache_dir'))
    end

    # Dynamically remove the highest instance of :var
    def remove_highest(var)
      @configs.each do |c|
        if c.has_var?(var)
          return c.remove_var(var)
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
        if c.has_var?(var)
          ret << c.remove_var(var)
        end
      end
      ret
    end
    alias_method :purge, :remove_all_instances

    # Dynamically add a new site variable at the highest priority.
    def add_as_highest(var, value)
      # Don't want to override anything, so just shift in a dummy site config instance at the highest level and
      # set the value there.
      c = Config.new(path: :runtime, parent: self, values: { var.to_s => value })
      configs.prepend(Config.new(path: :runtime, parent: self, values: { var.to_s => value }))
    end
    alias_method :[]=, :add_as_highest

    # Dynamically add a new site variable at the lowest priority.
    # Essentially, this sets a new default value.
    def add_as_lowest(var, value)
      # Don't want to override anything, so just shift in a dummy site config at the lowest level and
      # set the value there.
      configs.append(Config.new(path: :runtime, parent: self, values: { var.to_s => value }))
    end

    # Adds a new site config file as the highest priority
    def add_site_config_as_highest(site_config_file)
      # configs.prepend YAML.load_file(File.expand_path('../../../origen_site_config.yml', __FILE__))
      configs.prepend(Config.new(path: site_config_file, parent: self))
    end

    # Adds a new site config file as the highest priority
    def add_site_config_as_lowest(site_config_file)
      # configs.append YAML.load_file(File.expand_path('../../../origen_site_config.yml', __FILE__))
      configs.append(Config.new(path: site_config_file, parent: self))
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

    def get_all(val)
      ret = []
      @configs.each do |c|
        if c.has_var?(val)
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

    def refresh
      @configs.each(&:refresh)
    end

    def pretty_print_configs
      puts 'The following config files are ordered from last-encountered (highest priority) first-encountered (lowest priority)'
      puts
      configs.each_with_index do |config, i|
        puts "#{i}: #{config.path} (#{config.type})"
      end
    end
    alias_method :pp_configs, :pretty_print_configs

    def all_vars
      vars = {}
      configs.each do |c|
        vars = c.values.merge(vars)
      end
      vars
    end
    alias_method :env, :all_vars

    # Gets all config variables as a hash, but the hash's values are the Config instances which defines the highest
    # priority of each var, instead of the var's value itself.
    def vars_by_configs
      vars = {}
      configs.each do |c|
        vars = c.values.map { |k, v| [k, c] }.to_h.merge(vars)
      end
      vars
    end
    alias_method :vars_by_config, :vars_by_configs

    def pretty_print_env(*vars)
      puts
      spacing = ' ' * 2
      r = vars.empty? ? nil : Regexp.union(vars.map { |v| Regexp.new(v) })
      all_vars.each do |var, val|
        if !r.nil? && !(var.match r)
          next
        end

        if val.is_a?(Array)
          puts "#{var}: ["
          val.each { |v| puts "#{spacing} #{v}" }
          puts ']'
        elsif val.is_a?(Hash)
          puts "#{var}: {"
          val.each { |v| puts "#{spacing} #{v}" }
          puts '}'
        else
          puts "#{var}: #{val}"
        end
      end
      puts
    end
    alias_method :pp_env, :pretty_print_env

    def to_env(val)
      "ORIGEN_#{val.upcase}"
    end

    def env_contains?(val)
      ENV.key?(val)
    end

    def env(val)
      if env_contains?(val)
        ENV[val]
      end
    end

    def inspect_variable(*vars)
      vars.each do |var|
        puts "Inspecting Variable: #{var}"
        if env_contains?(to_env(var))
          puts "Environment Variable (#{to_env(var)}): #{env(to_env(var))}"
        else
          puts "(No enviornment variable #{to_env(var)} defined)"
        end
        @configs.each do |c|
          if c.has_var?(var)
            puts "#{c.path} (#{c.type}): #{c[var]}"
          end
        end
        puts
      end
    end
    alias_method :inspect_var, :inspect_variable
    alias_method :inspect_variables, :inspect_variable
    alias_method :inspect_vars, :inspect_variable

    # Inspects the config(s) at the incex given.
    def inspect_configs(*config_indexes)
      config_indexes.each do |i|
        if i.to_i > @configs.size
          puts "Origen::SiteConfig: index #{i} is out of range of the available configs! Total configs: #{@configs.size}.".red
        elsif i.to_i < 0
          puts "Origen::SiteConfig: index #{i} is less than 0. This index is ignored.".red
        else
          c = @configs[i.to_i]
          puts "Inspecting config \##{i}"
          puts "Type: #{c.type}"
          puts "Path: #{c.path}"
          if c.centralized?
            # Add a safeguard in case something happened being bootup and now and the cache is no longer present
            puts "Cached At: #{c.cache_file}" if c.cache_file
            puts "Cached On: #{c.cache_file.ctime}" if c.cache_file
          end

          puts
          puts 'Values from this config:'
          spacing = ' ' * 2
          c.values.each do |var, val|
            if val.is_a?(Array)
              puts "#{var}: ["
              val.each { |v| puts "#{spacing} #{v}" }
              puts ']'
            elsif val.is_a?(Hash)
              puts "#{var}: {"
              val.each { |v| puts "#{spacing} #{v}" }
              puts '}'
            else
              puts "#{var}: #{val}"
            end
          end

          puts
          puts 'Active (highest-level) values from this config:'
          spacing = ' ' * 2
          vars_by_config.select { |k, v| v == c }.map { |k, v| [k, v[k]] }.to_h.each do |var, val|
            if val.is_a?(Array)
              puts "#{var}: ["
              val.each { |v| puts "#{spacing} #{v}" }
              puts ']'
            elsif val.is_a?(Hash)
              puts "#{var}: {"
              val.each { |v| puts "#{spacing} #{v}" }
              puts '}'
            else
              puts "#{var}: #{val}"
            end
          end
          puts
        end
      end
    end
    alias_method :inspect_config, :inspect_configs

    def find_val(val, options = {})
      env = "ORIGEN_#{val.upcase}"
      if ENV.key?(env)
        value = ENV[env]
      else
        config = configs.find { |c| c.has_var?(val) }
        value = config ? config.find_val(val) : nil
      end

      unless NON_BOOLEAN_PARAMETERS.include?(val.to_s.downcase.to_sym)
        if TRUE_VALUES.include?(value)
          return true
        elsif FALSE_VALUES.include?(value)
          return false
        end
      end
      value
    end
    alias_method :get, :find_val
    alias_method :[], :find_val

    private

    def configs
      @configs ||= configs!
    end

    # Searches a directory and returns an array of config objects (from lowest to highest priority) that were found
    # @note This includes searching for <code>./config/</code> in <code>dir</code>. In other words, this searches both
    #  <code>dir</code> and <code>dir/config</code>.
    def load_directory(dir, prepend: false)
      [
        File.join(dir, 'config', 'origen_site_config.yml'),
        File.join(dir, 'config', 'origen_site_config.yml.erb'),
        File.join(dir, 'origen_site_config.yml'),
        File.join(dir, 'origen_site_config.yml.erb')
      ].each do |f|
        if File.exist?(f)
          if prepend
            configs.unshift(Config.new(path: f, parent: self))
          else
            configs << Config.new(path: f, parent: self)
          end
        end
      end
    end

    # Forces a reparse of the site configs.
    # This will set the @configs along the current path first,
    # then, using those values, will add a site config at the home directory.
    def configs!
      # This global is set when Origen is first required, it generally means that what is considered
      # to be the pwd for the purposes of looking for a site_config file is the place from where the
      # user invoked Origen. Otherwise if the running app switches the PWD it can lead to confusing
      # behavior - this was a particular problem when testing the new app generator which switches the
      # pwd to /tmp to build the new app
      path = $_origen_invocation_pwd
      @configs = []

      # Add any site_configs from where we are currently running from, i.e. the application
      # directory area
      until path.root?
        load_directory(path)
        path = path.parent
      end

      # Add and any site_configs from the directory hierarchy where Ruby is installed
      path = Pathname.new($LOAD_PATH.last)
      until path.root?
        load_directory(path)
        path = path.parent
      end

      # Add the one from the Origen core as the lowest priority, this one defines
      # the default values
      load_directory(File.expand_path('../../../', __FILE__))

      # Add the site_config from the user's home directory as highest priority, if it exists
      # But, make sure we take the site installation's setup into account.
      # That is, if user's home directories are somewhere else, make sure we use that directory to the find
      # the user's overwrite file. The user can then override that if they want."
      load_directory(File.expand_path(user_install_dir), prepend: true)

      # Load any centralized site configs now.
      centralized_site_config = find_val('centralized_site_config')
      if centralized_site_config
        # We know the last two site configs will exists (they are in Origen core) and that they contain the default
        # values. We want the centralized config to load right after those.
        @configs.insert(-3, Config.new(path: centralized_site_config, parent: self))
      end

      # After all configs have been populated, see if the centralized needs refreshing
      @configs.each { |c| c.refresh if c.needs_refresh? }

      @configs
    end
  end

  def self.site_config
    @site_config ||= SiteConfig.new
  end
end
