module Origen
  module Users
    class User
      require 'openssl'
      require 'digest/sha1'

      attr_reader :role
      attr_writer :name, :email

      def self.current_user_id
        `whoami`.strip
      end

      def self.current
        Origen.current_user
      end

      def initialize(*args)
        if args.last.is_a?(Symbol)
          @role = args.pop
        else
          @role = :user
        end
        if args.size == 2
          @name = args.first
        end
        id = args.pop
        if id.to_s =~ /(.*)@/
          @email = id
          @id = Regexp.last_match(1)
        else
          @id = id
        end
      end

      # Send the user an email
      #
      # @example
      #   User.current.send subject: "Complete", message: "Your job is done!"
      #   User.new("r49409").send subject: "Complete", message: "Your job is done!"
      def send(options)
        options[:body] ||= options[:message]
        options[:to] = self
        Origen.mailer.send_email(options)
      end

      def id
        @id.to_s.downcase
      end
      alias_method :core_id, :id

      # Returns true if the user is an admin for the current application
      def admin?
        role == :admin
      end

      # Returns true if the user is the current user
      def current?
        id.to_s.downcase == self.class.current_user_id
      end

      # Returns the user's initials in lower case
      def initials
        initials = name.split(/\s+/).map { |n| n[0].chr }.join('')
        initials.downcase
      end

      def name
        @name ||= ENV['ORIGEN_NAME'] || name_from_rc || @id
      end

      def name_from_rc
        RevisionControl::Git.user_name
      end

      def email
        if current?
          @email ||= ENV['ORIGEN_EMAIL'] || email_from_rc || begin
            if Origen.site_config.email_domain
              "#{id}@#{Origen.site_config.email_domain}"
            end
          end
        else
          @email ||= begin
            if Origen.site_config.email_domain
              "#{id}@#{Origen.site_config.email_domain}"
            end
          end
        end
      end

      def email_from_rc
        RevisionControl::Git.user_email
      end

      # Fetch user data from the FSL application directory
      #
      # @example
      #
      #   User.new("r49409").lookup.motunixdomain   # => ["cde-tx32.sps.mot.com"]
      def lookup(default = 'Unknown')
        data = Origen.ldap.lookup(self)
        if block_given?
          if data
            yield data
          else
            default
          end
        else
          data
        end
      end

      # Prints all raw data available on the given user from the FSL
      # application directory.
      #
      # Most of the useful data is already exposed through the available
      # user methods, but if you want to get any of these parameters they
      # can be fetched via the lookup method.
      def raw
        Origen.ldap.display(self)
        nil
      end
      alias_method :display, :raw

      def ==(user)
        if user.is_a?(Origen::Users::User)
          user.id == id
        elsif user.is_a?(String)
          user.downcase == id
        else
          super
        end
      end

      # Provides methods to access attributes available from LDAP
      def method_missing(method, *args, &block)
        l = Origen.ldap.lookup(self)
        if l
          if l.attribute_names.include?(method)
            l[method]
          else
            super
          end
        else
          super
        end
      end

      def respond_to?(method, include_private = false)
        super || begin
          if Origen.ldap.available?
            Origen.ldap.lookup(self) && Origen.ldap.lookup(self).attribute_names.include?(method.to_sym)
          else
            false
          end
        end
      end

      # Returns a string like "Stephen McGinty <Stephen.Mcginty@freescale.com>"
      def name_and_email
        "#{name} <#{email}>"
      end
    end
  end
end
