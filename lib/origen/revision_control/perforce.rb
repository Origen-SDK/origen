require 'P4'
module Origen
  module RevisionControl
    class Perforce < Base
      # P4 session
      attr_reader :p4

      # e.g. myfile.txt
      attr_accessor :remote_file

      def initialize(options = {})
        super
        @remotes_method = :print
        @p4 = P4.new
        @p4.maxresults = 1
        parse_remote
        @p4.connect
        unless @p4.connected?
          Origen.log.error("Could not connect to port #{@p4.port} on client #{@p4.client}!")
          fail
        end
        @p4.password = '@wsx-pl,0830'
        @p4.run_login
      end

      # Downloads a file to a local directory, no workspace/client is created.  Perfect
      # for read-only access like an application remote
      def print(options = {})
        options = {
          verbose: true,
          version: 'Latest'
        }.merge(options)
        cmd = [__method__.to_s, '-o', "#{@local}/#{@remote_file.to_s.split('/')[-1]}", @remote_file.to_s]
        run cmd
      end

      def checkout(path = nil, options = {})
        not_yet_supported
      end

      def root
        not_yet_supported
      end

      def current_branch
        not_yet_supported
      end

      def diff_cmd
        not_yet_supported
      end

      def unmanaged
        not_yet_supported
      end

      def local_modifications
        not_yet_supported
      end

      def changes
        not_yet_supported
      end

      def checkin
        not_yet_supported
      end

      def build
        not_yet_supported
      end

      private

      # Needs to be in the form of an Array with command, as a Sting, as the first argument
      # e.g. ["print", "-o", "pins/myfile.txt", "//depot/myprod/main/doc/pinout/myfile.txt"]
      def run(cmd)
        p4.run cmd
      end

      def not_yet_supported
        Origen.log.warn("The method #{__method__} is not currently supported by the Perforce API")
        nil
      end

      def parse_remote
        (@p4.port, @remote_file) = @remote.to_s.match(/^p4\:\/\/(\S+\:\d+)(.*)/).captures unless @remote.nil?
      end

      def configure_client(options)
        unless options.include? :local
          Origen.log.error('Need options[:local] to know how to configure the Perforce client!')
          fail
        end
        client_name = "#{Origen.app.name}_#{User.current.id}_#{Time.now.to_i}"
        begin
          client_spec = @p4.fetch_client
          client_spec['Root'] = options[:local].to_s
          client_spec['Client'] = client_name
          client_spec['View'] = ["#{@remote_file} //#{client_name}/#{@remote_file.split('/')[-1]}"]
          client_spec['Host'] = nil
          @p4.save_client(client_spec)
          @p4.client = client_name
        rescue P4Exception
          @p4.errors.each { |e| Origen.log.error e }
          raise
        end
      end
    end
  end
end
