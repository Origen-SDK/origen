module RGen
  # Methods related to individual users and groups
  module Users
    autoload :User,   'rgen/users/user'
    autoload :ApplicationDirectory,   'rgen/users/application_directory'

    def app_users
      # Had to do some shenanigans here due to RGen.root not being available
      # when this file is included, only load the users from the app once a user
      # method is first called
      return @app_users if @app_users
      require File.join(RGen.root, 'config', 'users')
      @app_users = users
    end

    # Returns a user object representing the current user, will return a default
    # user object if the current user is not known to the generator
    def current_user
      core_id = RGen::Users::User.current_user_id
      user = app_users.find { |user| user.core_id == core_id }
      user || User.new(core_id)
    end

    # Returns all admin user objects
    def admins
      app_users.select(&:admin?)
    end
    alias_method :developers, :admins
  end
end
