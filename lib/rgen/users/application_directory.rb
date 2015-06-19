module RGen
  module Users
    # Interface to talk to the FSL Application Directory, an instance of this class is available
    # at RGen.fsl.
    #
    # This provides APIs to lookup public information about any user (email, phone number, etc)
    # and to authenticate the current user using the LDAP system.
    class ApplicationDirectory
      require 'io/console'
      require 'base64'
      require 'net-ldap'

      SERVICE_ACCOUNT = 'TBD'
      SERVICE_PASS = 'TBD'

      HOST = 'TBD'
      PORT = 'TBD'
      BASE_DN = 'TBD'

      # Lookup the given user in the core directory and return an object representing the user's entry
      # in the FSL application directory, run the display method from the console to see the field
      # names and what information is available.
      # The record for the given user will be cached the first time it is generated, so this method can be
      # repeatedly called from the same thread without incurring a remote fetch each time.
      #
      #     entry = RGen.fsl.lookup("r49409")
      #     entry.mail   # => stephen.mcginty@freescale.com
      def lookup(user_or_core_id = RGen.current_user)
        core_id = core_id(user_or_core_id)
        unless instance_variable_defined?("@#{core_id.downcase}")
          record = service.search(base: BASE_DN, filter: "uid=#{core_id}").first
          instance_variable_set("@#{core_id.downcase}", record)
        end
        instance_variable_get("@#{core_id.downcase}")
      end

      # Lookup a user by name
      #
      #   RGen.fsl.find_by_name("Stephen McGinty")
      def find_by_name(name)
        name = alias_for(name)
        filter = Net::LDAP::Filter.eq('cn', "*#{name.gsub(' ', '*')}*")
        user = service.search(base: BASE_DN, filter: filter).first
        return User.new(user.uid.first) if user
        # Try again with first name and last name
        first_name = Net::LDAP::Filter.eq('motdisplayfirstname', name.split(/\s/).first)
        last_name = Net::LDAP::Filter.eq('motdisplaylastname', name.split(/\s/).last)
        filter = Net::LDAP::Filter.join(first_name, last_name)
        user = service.search(base: BASE_DN, filter: filter).first
        return User.new(user.uid.first) if user
        # Finally try for a match by email
        filter = Net::LDAP::Filter.eq('mail', "*#{name.gsub(' ', '*')}*")
        user = service.search(base: BASE_DN, filter: filter).first
        return User.new(user.uid.first) if user
      end

      # Prints out the information available for the given core, this is useful to work out the name
      # of the information that you want to pull from the object returned from lookup
      def display(user_or_core_id = RGen.current_user)
        lookup(user_or_core_id).each do |attribute, values|
          puts "   #{attribute}:"
          values.each do |value|
            puts "      --->#{value}"
          end
        end
      end

      # Authenticates the current user via their password - will return true if they authenticate,
      # otherwise the program will terminate
      def authenticate(options = {})
        options = {
        }.merge(options)
        core_id = RGen.current_user.core_id
        authenticated = false
        timeout = false
        x = 0
        until authenticated || timeout
          password = options[:password] || get_password
          options[:password] = nil
          ldap = Net::LDAP.new host:       HOST,
                               port:       PORT,
                               encryption: :simple_tls,
                               #:auth => { :method => :simple, :username => lookup(core_id).dn, :password => password }
                               # Believe the DN's are all the same, so save a lookup
                               auth:       { method: :simple, username: "motguid=#{core_id.upcase},#{BASE_DN}", password: password }
          if ldap.bind
            authenticated = true
            if @new_password
              puts 'valid!'
              @new_password = false
            end
          else
            puts 'Sorry that password is not valid'
            password = nil
            destroy_session
            if x == 3
              puts 'Sorry we cannot continue without a valid password'
              exit 1
            end
            x += 1
          end
        end
        true
      end

      private

      def alias_for(name)
        RGen.app.config.user_aliases.each do |nick, real|
          if name.to_s.downcase.delete(' ') == nick.to_s.downcase.delete(' ')
            return real
          end
        end
        name
      end

      def core_id(user_or_core_id)
        user_or_core_id.respond_to?(:core_id) ? user_or_core_id.core_id : user_or_core_id
      end

      def get_password
        @new_password = true
        puts 'Please enter your password:'
        password = (STDIN.noecho(&:gets) || '').chomp
        print 'Checking...'
        password
      end

      def service
        @service ||= Net::LDAP.new host:       HOST,
                                   port:       PORT,
                                   encryption: :simple_tls,
                                   auth:       { method: :simple, username: SERVICE_ACCOUNT, password: SERVICE_PASS }
      end
    end
  end
end
