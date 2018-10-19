require 'net/smtp'
module Origen
  module Utility
    class Mailer
      include Users

      # Generic method to send an email, alternatively use one of the
      # pre-defined mail types using the other methods.
      def send_email(options = {})
        options = { server:         Origen.site_config.email_server,
                    port:           Origen.site_config.email_port,
                    from:           current_user.email,
                    from_alias:     current_user.name,
                    subject:        'Hello',
                    body:           'Hello from Origen!',
                    to:             current_user.email,
                    authentication: (Origen.site_config.email_authentication || :none).to_sym,
                    auth_user:      (Origen.site_config.email_auth_user      || current_user.email),
                    auth_password:  (Origen.site_config.email_auth_password  || current_user.password),
                    domain:         (Origen.site_config.email_domain         || ''),
                  }.merge(options)

        # Force to an array
        to = options[:to].respond_to?('each') ? options[:to] : [options[:to]]

        # Convert any user objects to an email
        to = to.map { |obj| obj.respond_to?('email') ? obj.email : obj }

        to.uniq.each do |addr|
          msg = <<END_OF_MESSAGE
From: #{options[:from_alias]} <#{options[:from]}>
To: #{addr}
Subject: #{options[:subject]}

#{options[:body]}
END_OF_MESSAGE

          begin
            Origen.log.debug("Origen::Utility::Mailer Setup:")
            options.each { |k, v| Origen.log.debug("  #{k}: #{v}") }
            
            #Net::SMTP.start(options[:server], options[:port]) do |smtp|
            #  smtp.send_message msg, options[:from], addr
            #end

            # Exceptions raised here will be caught by rescue clause
            smtp = Net::SMTP.new(options[:server], options[:port])
            smtp.enable_starttls if options[:authentication] != :none
            
            opts = begin
              if options[:authentication] == :none
                # Trying to add username and password if there's no authentication will actually be rejected by
                # the server.
                [options[:domain]]
              else
                [options[:domain], options[:auth_user], options[:auth_password], options[:authentication]]
              end
            end
            
            smtp.start(*opts) do |m|
              m.send_message(msg, options[:from], addr)
            end
            
            # Exceptions raised here will be caught by rescue clause
            #smtp = Net::SMTP.new(options[:server], options[:port])
            #smtp.enable_starttls
            
            #smtp.start (options[:domain], options[:auth_user], options[:auth_password], options[:authentication]) do |smtp|
            #  smtp.send_message(msg, options[:from], addr)
            #end
          rescue
            warn "Email not able to be sent to address '#{addr}'"
          end
        end
      end

      # Call to send a notice
      def send_release_notice(version, release_note, type, selectors, options = {})
        if external?(type)
          header = "A new version of #{config.name} is available:"
        else
          header = "A new development version of #{config.name} is available:"
        end

        msg = <<-END1
Hi,

#{header}

    #{version}    #{selectors}

Release note:

--------------------------------------------------------------------------------------

#{release_note}

--------------------------------------------------------------------------------------
          END1

        if config.release_instructions
          msg += <<-END2

#{config.release_instructions}

--------------------------------------------------------------------------------------
            END2
        end

        msg += <<-END3

You are receiving this because you are a member of the #{config.name} Mailing List,
or a member of the development team.
END3

        if external?(type)
          to = Origen.app.maillist_prod + Origen.app.maillist_dev
          if config.release_email_subject
            subject = "[#{Origen.app.namespace}] New Official Release: #{config.release_email_subject}"
          else
            subject = "[#{Origen.app.namespace}] New Official Release"
          end
        else
          to = Origen.app.maillist_dev
          if config.release_email_subject
            subject = "[#{Origen.app.namespace}] New Development Tag: #{config.release_email_subject}"
          else
            subject = "[#{Origen.app.namespace}] New Development Tag"
          end
        end

        begin
          send_email({ to: to, subject: subject, body: msg }.merge(options))
        rescue
          warn "Email could not be sent to #{to}"
        end
      end

      # Send a regression complete notice,
      def send_regression_complete_notice(stats = Origen.app.runner.stats, options = {})
        stats, options = Origen.app.runner.stats, stats if stats.is_a?(Hash)
        options = {
          to: current_user
        }.merge(options)

        msg = <<-END1
Hi,

The regression results are:

#{stats.summary_text}

        END1

        subject = "[#{Origen.app.namespace}] Regression - "
        if stats.clean_run?
          subject += 'PASSED'
        else
          subject += 'FAILED'
        end
        send_email({ to: options[:to], subject: subject, body: msg }.merge(options))
      end

      private

      def config
        Origen.config
      end

      def external?(type)
        [:production, :major, :minor, :tiny, :bugfix].include?(type)
      end
    end
  end
end
