module RGen
  module Users
    class User
      require 'openssl'
      require 'digest/sha1'

      attr_reader :role

      def self.current_user_id
        core_id = `whoami`.strip
        # Remove domain prefix from windows env
        core_id.gsub('fsl\\', '').downcase
      end

      def self.current
        RGen.current_user
      end

      def self.find_by_name(*args)
        RGen.fsl.find_by_name(*args)
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
        @core_id = args.pop
      end

      # Send the user an email
      #
      # @example
      #   User.current.send subject: "Complete", message: "Your job is done!"
      #   User.new("r49409").send subject: "Complete", message: "Your job is done!"
      def send(options)
        options[:body] ||= options[:message]
        options[:to] = self
        RGen.mailer.send_email(options)
      end

      def core_id
        @core_id.to_s.downcase
      end
      alias_method :r_number, :core_id

      # Returns true if the user is an admin for the current application
      def admin?
        role == :admin
      end

      # Returns true if the user is the current user
      def current?
        core_id.to_s.downcase == self.class.current_user_id
      end

      # Returns the password for the current user, otherwise nil
      def password
        if current?
          RGen.fsl.password
        end
      end

      # Returns the user's initials in lower case
      def initials
        initials = name.split(/\s+/).map { |n| n[0].chr }.join('')
        initials.downcase
      end

      def name
        lookup do |lookup|
          lookup.motcommonnames.first.sub("-#{core_id}".upcase, '')
        end
      end

      def email
        "#{core_id}@freescale.com"
      end

      def department
        lookup do |lookup|
          lookup.department.first
        end
      end

      def country
        lookup do |lookup|
          lookup.c.first
        end
      end

      def location_code
        lookup do |lookup|
          lookup.motlocationcode.first
        end
      end

      def commerceid
        lookup do |lookup|
          lookup.motcommerceid.first
        end
      end

      def mbg
        lookup do |lookup|
          lookup.ou.first
        end
      end

      def group
        lookup do |_lookup|
          a = RGen.fsl.lookup(@core_id).motorglevel3.to_s
          "#{a[2..-3]}"
        end
      end

      def phone_number
        lookup do |lookup|
          lookup.telephonenumber.first
        end
      end
      alias_method :telephonenumber, :phone_number
      alias_method :telephone_number, :phone_number

      # Fetch user data from the FSL application directory
      #
      # @example
      #
      #   User.new("r49409").lookup.motunixdomain   # => ["cde-tx32.sps.mot.com"]
      def lookup(default = 'Unknown')
        data = RGen.fsl.lookup(self)
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
        RGen.fsl.display(self)
        nil
      end
      alias_method :display, :raw

      # Details method will produce the following output
      #
      #   >> User.current.details
      #   ****************************************************
      #   1. Name                   : Stephen McGinty
      #   2. Core ID                : r49409
      #   3. E-Mail Address         : Stephen.Mcginty@freescale.com
      #   4. Department             : TZ918
      #   5. Country                : GBR
      #   6. Commerce Id            : 18007364
      #   7. Location Code          : ZUK07
      #   8. MBG                    : AMCU
      #   9. Telephone No           : +441355355868
      #   ****************************************************
      def details
        puts '****************************************************'
        puts "1. Name                   : #{name}"
        puts "2. Core ID                : #{core_id}"
        puts "3. E-Mail Address         : #{email}"
        puts "4. Department             : #{department}"
        puts "5. Country                : #{country}"
        puts "6. Commerce Id            : #{commerceid}"
        puts "7. Location Code          : #{location_code}"
        puts "8. MBG                    : #{mbg}"
        puts "9. Telephone No           : #{phone_number}"
        puts '****************************************************'
      end

      def ==(user)
        if user.is_a?(RGen::Users::User)
          user.core_id == core_id
        elsif user.is_a?(String)
          user.downcase == core_id
        else
          super
        end
      end

      # Implements methods like user.motunixdomain
      def method_missing(method, *args, &block)
        l = RGen.fsl.lookup(self)
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

      def respond_to?(method)
        super || (RGen.fsl.lookup(self) && RGen.fsl.lookup(self).attribute_names.include?(method.to_sym))
      end

      # Returns a string like "McGinty Stephen-R49409 <Stephen.Mcginty@freescale.com>"
      def name_and_email
        "#{displayname.first} <#{mail.first}>"
      end
    end
  end
end
