module Origen
  module Users
    # Interface to talk to a company's LDAP-based employee directory, an instance of this class is available
    # at Origen.ldap
    #
    # This provides APIs to lookup public information about any user (email, phone number, etc)
    class LDAP
      require 'io/console'
      require 'base64'
      require 'net-ldap'

      SERVICE_ACCOUNT = Origen.site_config.ldap_username
      SERVICE_PASS = Origen.site_config.ldap_password

      HOST = Origen.site_config.ldap_host
      PORT = Origen.site_config.ldap_port
      BASE_DN = Origen.site_config.ldap_base_dn

      def available?
        !!(SERVICE_ACCOUNT && SERVICE_PASS && HOST && PORT && BASE_DN)
      end

      # Lookup the given user in the core directory and return an object representing the user's entry
      # in the FSL application directory, run the display method from the console to see the field
      # names and what information is available.
      # The record for the given user will be cached the first time it is generated, so this method can be
      # repeatedly called from the same thread without incurring a remote fetch each time.
      #
      #     entry = Origen.fsl.lookup("r49409")
      #     entry.mail   # => stephen.mcginty@freescale.com
      def lookup(user_or_id = Origen.current_user)
        id = id(user_or_id)
        unless instance_variable_defined?("@#{id.downcase}")
          record = service.search(base: BASE_DN, filter: "#{Origen.site_config.ldap_user_id_attribute || 'id'}=#{id}").first
          instance_variable_set("@#{id.downcase}", record)
        end
        instance_variable_get("@#{id.downcase}")
      end

      # Prints out the information available for the given core, this is useful to work out the name
      # of the information that you want to pull from the object returned from lookup
      def display(user_or_id = Origen.current_user)
        lookup(user_or_id).each do |attribute, values|
          puts "   #{attribute}:"
          values.each do |value|
            puts "      --->#{value}"
          end
        end
      end

      private

      def id(user_or_id)
        user_or_id.respond_to?(:id) ? user_or_id.id : user_or_id
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
