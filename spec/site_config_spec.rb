require 'spec_helper'
require 'etc'

describe "Origen.site_config" do

  # Make sure that cached site config values don't affect these or the
  # next tests
  before :all do
    clear_site_config
  end

  def clear_site_config
    # Reset the site config
    Origen.site_config.instance_variable_set('@configs', Array.new)
    
    # Also, reset the relevant environment variables
    ENV['ORIGEN_GEM_INSTALL_DIR'] = nil
    ENV['ORIGEN_USER_GEM_DIR'] = nil
    ENV['ORIGEN_HOME_DIR'] = nil
    ENV['ORIGEN_USER_INSTALL_DIR'] = nil
  end

  # formulates the path for the OS.
  # e.g. '/example/path'
  # => '/example/path' (Linux/Mac)
  # => 'C:/example/path' (Windows)
  def to_os_path(path, options={})
    if Origen.running_on_windows?
      drive = home.split(File::SEPARATOR)[0]
      "#{drive}#{path}"
    else
      path
    end
  end

  def username
    Etc.getlogin
  end
  
  def home
    File.expand_path '~/'
  end

  def with_env_variable(var, value)
    orig = ENV[var]
    ENV[var] = value
    yield
    ENV[var] = orig
  end

  def add_config_variable(var, value)
    Origen.site_config.instance_variable_get('@configs').prepend({var => value})
  end
  
  def remove_config_variable(var)
    Origen.site_config.remove_config_variable(var)
  end

  it "converts true/false values from environment variables to booleans" do
    with_env_variable("ORIGEN_GEM_MANAGE_BUNDLER", "false") do
      ENV["ORIGEN_GEM_MANAGE_BUNDLER"].should == "false"
      Origen.site_config.gem_manage_bundler.should == false
    end
    with_env_variable("ORIGEN_GEM_MANAGE_BUNDLER", "true") do
      ENV["ORIGEN_GEM_MANAGE_BUNDLER"].should == "true"
      clear_site_config
      Origen.site_config.gem_manage_bundler.should == true
    end
  end
  
  it "allows user overrides" do
    add_config_variable('test', 'test value')
    Origen.site_config.test.should == 'test value'
    
    with_env_variable("ORIGEN_TEST", "Origen Test Value") do
      ENV["ORIGEN_TEST"].should == "Origen Test Value"
      Origen.site_config.test.should == "Origen Test Value"
    end
  end
  
  describe 'Site config as it relates to install directories' do
    it 'has method :gem_install_dir (for legacy) aliased to method :user_gem_dir' do
      expect(Origen.site_config.method(:gem_install_dir)).to eql(Origen.site_config.method(:user_gem_dir))
    end
    
    context 'with default site config' do
      before :context do
        clear_site_config
        
        # Create a blank site config
        Origen.site_config.home_dir
        
        # Remove the instances of home_dir, user_install_dir, user_gem_dir, and gem_install_dir
        # that may be present in the user's site configs by default.
        Origen.site_config.remove_all_instances('home_dir')
        Origen.site_config.remove_all_instances('user_install_dir')
        Origen.site_config.remove_all_instances('user_gem_dir')
        Origen.site_config.remove_all_instances('gem_install_dir')
      end
      
      after :context do
        clear_site_config
      end
      
      it 'sets home_dir to ~/ by default' do
        expect(Origen.site_config.home_dir).to eql("#{home}/.origen")
        expect(Origen.home).to eql("#{home}/.origen")
      end
      
      it 'sets user_install_dir to /home/<username>/.origen by default' do
        expect(Origen.site_config.user_install_dir).to eql("#{home}/.origen")
      end
      
      it 'sets user_gem_dir to /home/<username>/.origen/gems by default' do
        expect(Origen.site_config.user_gem_dir).to eql("#{home}/.origen/gems")
      end
    end
    
    context 'with overriden gem_install_dir' do
      before :context do
        add_config_variable('gem_install_dir', '/gem_location/')
      end
      
      after :context do
        clear_site_config
      end
      
      it 'leaves home_dir as the default' do
        expect(Origen.site_config.home_dir).to eql("#{home}/.origen")
        expect(Origen.home).to eql("#{home}/.origen")
      end
      
      it 'leaves the user_install_dir as the default' do
        expect(Origen.site_config.user_install_dir).to eql("#{home}/.origen")
      end
      
      it 'changes the user_gem_dir' do
        expect(Origen.site_config.user_gem_dir).to eql(to_os_path("/gem_location/.origen/gems"))
      end
    end
    
    context 'with overriden gem_install_dir AND overriden user_gem_dir' do
      before :context do
        add_config_variable('gem_install_dir', '/gem_location/')
        add_config_variable('user_gem_dir', '/user_location')
      end
      
      after :context do
        clear_site_config
      end
    
      it 'leaves home_dir as the default' do
        expect(Origen.site_config.home_dir).to eql("#{home}/.origen")
        expect(Origen.home).to eql("#{home}/.origen")
      end
      
      it 'leaves the user_install_dir as the default' do
        expect(Origen.site_config.user_install_dir).to eql("#{home}/.origen")
      end
      
      it 'uses :user_gem_dir over :gem_install_dir' do
        expect(Origen.site_config.user_gem_dir).to eql(to_os_path("/user_location/.origen/gems"))
      end
    end
    
    context 'with overriden :user_gem_dir AND ENV variable ORIGEN_USER_GEM_DIR set' do
      before :context do
        add_config_variable('gem_install_dir', '/gem_location/')
        add_config_variable('user_gem_dir', '/user_location')
      end
      
      after :context do
        clear_site_config
      end
      
      it 'uses ORIGEN_USER_GEM_DIR over :user_gem_dir' do
        with_env_variable 'ORIGEN_USER_GEM_DIR', '/user_env_location' do
          expect(Origen.site_config.user_gem_dir).to eql(to_os_path("/user_env_location/.origen/gems"))
        end
      end
    end
    
    context 'with overriden :user_install_dir overrriden' do
      before :context do
        clear_site_config
        
        add_config_variable('user_install_dir', '/user/install/dir')
      end
      
      it 'moves the :user_install_dir' do
        expect(Origen.site_config.home_dir).to eql("#{home}/.origen")
        expect(Origen.home).to eql("#{home}/.origen")
      end
      
      it 'moves the home_dir as well' do
        expect(Origen.site_config.user_install_dir).to eql(to_os_path('/user/install/dir/.origen'))
      end
      
      it 'leaves the :user_gem_install alone' do
        expect(Origen.site_config.user_gem_dir).to eql("#{home}/.origen/gems")
      end
    end
    
    context 'with home_dir overriden' do
      before :context do
        clear_site_config
        
        add_config_variable('home_dir', '/home/dir/')
      end
      
      it 'moves the home_dir' do
        expect(Origen.site_config.home_dir).to eql(to_os_path("/home/dir/.origen"))
        expect(Origen.home).to eql(to_os_path("/home/dir/.origen"))
      end
      
      it 'moves the :user_install_dir as well' do
        expect(Origen.site_config.user_install_dir).to eql(to_os_path('/home/dir/.origen'))
      end
      
      it 'also moves the :user_gem_install' do
        expect(Origen.site_config.user_gem_dir).to eql(to_os_path('/home/dir/.origen/gems'))
      end
    end
    
    context 'with home_dir, user_gem_dir, and user_install_dir all overriden' do
      before :context do
        clear_site_config
        
        add_config_variable('home_dir', '/home/location/')
        add_config_variable('user_install_dir', '/user/install')
        add_config_variable('gem_install_dir', '/gem/location/')
        add_config_variable('user_gem_dir', '/user/location')
      end
      
      it 'moves the home_dir' do
        expect(Origen.site_config.home_dir).to eql(to_os_path("/home/location/.origen"))
        expect(Origen.home).to eql(to_os_path("/home/location/.origen"))
      end
      
      it 'moves the :user_install_dir as well' do
        expect(Origen.site_config.user_install_dir).to eql(to_os_path('/user/install/.origen'))
      end
      
      it 'also moves :user_gem_dir' do
        expect(Origen.site_config.user_gem_dir).to eql(to_os_path('/user/location/.origen/gems'))
      end
    end
  end
  
  describe 'Site config install directories with ENV variables set' do
    # Make sure the ENV variables correctly overwrite the site config variables.
    # These use methods instead, so this moreso making sure the top method works rather than the
    # underlying find_val.
    context 'with ORIGEN_GEM_INSTALL_DIR set' do
      before :context do
        # Need to clear the site config and environment variables in the event that :user_gem_dir is actually set
        clear_site_config
        
        ENV['ORIGEN_GEM_INSTALL_DIR'] = '/env/gem/'
      end
      
      it 'uses the value in ORIGEN_GEM_INSTALL_DIR instead of :gem_install_dir' do
        expect(Origen.site_config.user_gem_dir).to eql(to_os_path("/env/gem/.origen/gems"))
      end
      
      it 'uses the value in :user_gem_dir instead of ORIGEN_GEM_INSTALL_DIR since :user_gem_dir takes precedenece' do
        ENV['ORIGEN_USER_GEM_DIR'] = '/env/user/gem/'
        expect(Origen.site_config.user_gem_dir).to eql(to_os_path("/env/user/gem/.origen/gems"))
      end
      
      after :context do
        ENV['ORIGEN_GEM_INSTALL_DIR'] = nil
        ENV['ORIGEN_USER_GEM_DIR'] = nil
      end
    end
    
    context 'with ORIGEN_HOME_DIR set' do
      before :context do
        clear_site_config
      end
      
      it 'uses the value in ORIGEN_HOME_DIR instead of :home_dir' do
        with_env_variable('ORIGEN_HOME_DIR', '/proj/env/~') do
          expect(Origen.site_config.home_dir).to eql(to_os_path("/proj/env/#{username}/.origen"))
          expect(Origen.home).to eql(to_os_path("/proj/env/#{username}/.origen"))
          expect(Origen.site_config.user_install_dir).to eql(to_os_path("/proj/env/#{username}/.origen"))
          expect(Origen.site_config.user_gem_dir).to eql(to_os_path("/proj/env/#{username}/.origen/gems"))
        end
      end
    end
    
    context 'with ORIGEN_HOME_DIR, ORIGEN_USER_INSTALL_DIR, and ORIGEN_USER_GEM_DIR all set' do
      before :context do
        clear_site_config
        
        ENV['ORIGEN_HOME_DIR'] = '/env/home/~'
        ENV['ORIGEN_USER_INSTALL_DIR'] = '/env/install/~'
        ENV['ORIGEN_USER_GEM_DIR'] = '/env/gem/~'
      end
      
      it 'uses the home_dir in ORIGEN_HOME_DIR' do
        expect(Origen.site_config.home_dir).to eql(to_os_path("/env/home/#{username}/.origen"))
        expect(Origen.home).to eql(to_os_path("/env/home/#{username}/.origen"))
      end
      
      it 'uses the user_install_dir in ORIGEN_USER_INSTALL_DIR' do
        expect(Origen.site_config.user_install_dir).to eql(to_os_path("/env/install/#{username}/.origen"))
      end
      
      it 'uses the user_gem_dir in ORIGEN_USER_GEM_DIR' do
        expect(Origen.site_config.user_gem_dir).to eql(to_os_path("/env/gem/#{username}/.origen/gems"))
      end
            
      after :context do
        ENV['ORIGEN_HOME_DIR'] = nil
        ENV['ORIGEN_USER_INSTALL_DIR'] = nil
        ENV['ORIGEN_USER_GEM_DIR'] = nil
      end
    end
  end
  
  describe 'Evaluating paths for directories' do
    context 'with basic values' do
      it 'uses the path given as is, and appends .origen to it' do
        expect(Origen.site_config.eval_path('/my/path')).to eql(to_os_path('/my/path/.origen'))
      end
      
      it 'does not append .origen if .origen is already provided in the path' do
        expect(Origen.site_config.eval_path('/my/path/.origen')).to eql(to_os_path('/my/path/.origen'))
      end
      
      it 'evaluates the path ~/ (default) to the home directory (or C: for Windows)' do
        expect(Origen.site_config.eval_path('~/')).to eql("#{home}/.origen")
      end
    end
    
    context 'using ~ in paths' do
      it 'replaces ~ with <username> and appending .origen' do
        expect(Origen.site_config.eval_path('/proj/origen/~')).to eql(to_os_path("/proj/origen/#{username}/.origen"))
      end
      
      it 'replace all ~ with <username> and appending .origen' do
        expect(Origen.site_config.eval_path('/proj/~/origens/~')).to eql(to_os_path("/proj/#{username}/origens/#{username}/.origen"))
      end
      
      it 'replaces leading ~ with <username> and appending .origen' do
        expect(Origen.site_config.eval_path('~/origens/~')).to eql("#{home}/origens/#{username}/.origen")
      end
      
      it 'allows ~ to be esacped' do
        expect(Origen.site_config.eval_path('~/\~/~')).to eql("#{home}/~/#{username}/.origen")
      end
      
      it 'allows leading ~ to be escaped' do
        expect(Origen.site_config.eval_path('\~/~')).to eql("~/#{username}/.origen")
      end
    end
    
    context 'with :append_dot_origen set to values' do
      before :context do
        clear_site_config
        
        # Only bring in the default site config at the root of Origen.
        Origen.site_config.add_site_config_as_highest("#{Origen.app.root}/origen_site_config.yml")
      end
      
      it 'is set to true by default' do
        expect(Origen.site_config.append_dot_origen).to be true
      end
      
      it 'does not append .origen when set to false' do
        add_config_variable('append_dot_origen', 'false')
        
        expect(Origen.site_config.append_dot_origen).to be false
        expect(Origen.site_config.home_dir).to eql("#{home}")
      end
      
      it 'appends whatever append_dot_origen is when it does not equal true or false (TRUE/FALSE/0/1)' do
        add_config_variable('append_dot_origen', '.test')

        expect(Origen.site_config.append_dot_origen).to eql('.test')
        expect(Origen.site_config.home_dir).to eql("#{home}/.test")
      end
      
      it 'still appends /gems to :user_gem_dir' do
        expect(Origen.site_config.user_gem_dir).to eql("#{home}/.test/gems")
      end
    end
      
    context 'with :append_gems set to values' do
      before :context do
        clear_site_config
        
        # Only bring in the default site config at the root of Origen.
        Origen.site_config.add_site_config_as_highest("#{Origen.app.root}/origen_site_config.yml")
      end
      
      it 'is set to true by default' do
        expect(Origen.site_config.append_gems).to be true
      end
      
      it 'does not append \'gems\' when set to false' do
        add_config_variable('append_gems', 'false')
        
        expect(Origen.site_config.append_gems).to be false
        expect(Origen.site_config.user_gem_dir).to eql("#{home}/.origen")
      end
      
      it 'appends whatever append_gems is when it does not equal true or false (TRUE/FALSE/0/1)' do
        add_config_variable('append_gems', 'user_gems')
        
        expect(Origen.site_config.user_gem_dir).to eql("#{home}/.origen/user_gems")
      end
    end
  end
  
  describe 'Site Config Dynamic Methods' do
    context 'with dynamically built site config' do
      it 'can dynamically add a new site config value as the highest priority' do
        # Add a new variable
        Origen.site_config.add_as_highest('new_highest', 'new value')
        expect(Origen.site_config.new_highest).to eql('new value')
        
        # Add it again, making sure that it is the new highest value
        Origen.site_config.add_as_highest('new_highest', 'newer value')
        expect(Origen.site_config.new_highest).to eql('newer value')
      end
      
      it 'can dynamically add a new site config value as the lowest priority' do
        Origen.site_config.add_as_lowest('new_lowest', 'new value')
        expect(Origen.site_config.new_lowest).to eql('new value')
        
        Origen.site_config.add_as_lowest('new_lowest', 'newer value')
        expect(Origen.site_config.new_lowest).to eql('new value')
      end
      
      it 'can dynamically add a new site config value using index notation' do
        Origen.site_config['new_index'] = 'new index value'
        expect(Origen.site_config.new_index).to eql('new index value')
      end
      
      it 'can dynamically add a new highest priority value using index notation' do
        Origen.site_config['new_index'] = 'newer index value'
        expect(Origen.site_config.new_index).to eql('newer index value')
      end
      
      it 'can retrieve a site config variable\'s current value' do
        expect(Origen.site_config.get('new_lowest')).to eql('new value')
      end
      
      it 'can retrieve a site config variable\'s current value, and list of values in order of priority' do
        expect(Origen.site_config.get_all('new_lowest')).to eql(['new value', 'newer value'])
      end
      
      it 'can retreive a site config variable\'s current value using index notation []' do
        expect(Origen.site_config['new_index']).to eql('newer index value')
      end
      
      it 'gets nil if the requested variable is not in the site config' do
        expect(Origen.site_config['unknown_value']).to be_nil
      end
      
      it 'gets an empty array if the requested variable is not in the site config' do
        expect(Origen.site_config.get_all('unknown_value')).to be_empty
      end
      
      it 'can dynamically remove the highest priority of a config variable' do
        val = Origen.site_config.remove_highest('new_lowest')
        expect(Origen.site_config.new_lowest).to eql('newer value')
        expect(val).to eql('new value')
      end
      
      it 'returns nil if the requested variable is not in the site config' do
        expect(Origen.site_config.remove_highest('unknown_value')).to be_nil
      end
      
      it 'can dynamically purge a config variable from the site config' do
        vals = Origen.site_config.purge('new_highest')
        expect(Origen.site_config.new_highest).to be(nil)
        expect(vals).to eql(['newer value', 'new value'])
      end
      
      it 'returns an empty array if the requested variable is not in the site config' do
        expect(Origen.site_config.purge('unknown_value')).to be_empty
      end
      
      it 'has method :purge aliased to :remove_all_instances' do
        expect(Origen.site_config.method(:purge)).to eql(Origen.site_config.method(:remove_all_instances))
      end
      
      it 'can clear the existing site config' do
        Origen.site_config.clear
        expect(Origen.site_config.instance_variable_get('@configs')).to be_empty
      end
    end
  end  
end
