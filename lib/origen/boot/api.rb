# Helper methods here and in the required files can be used by Origen during the bootup process.
# (e.g., in site config ERB files)
# This can be expanded as needed to provide more helpers.
module Origen
  # NOTE: Gems are not allowed to be required here, only Ruby stlibs
  require 'socket'
  require_relative '../operating_systems'

  # Platform independent means of retrieving the hostname
  def self.hostname
    # gethostbyname is deprecated in favor of Addrinfo#getaddrinfo
    # rubocop:disable Lint/DeprecatedClassMethods
    Socket.gethostbyname(Socket.gethostname).first.downcase
    # rubocop:enable Lint/DeprecatedClassMethods
  end
end
