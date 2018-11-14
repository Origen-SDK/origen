# Helper methods here and in the required files can be used by Origen during the bootup process.
# (e.g., in site config ERB files)
# This can be expanded as needed to provide more helpers.

module Origen
  require 'socket'
  require_relative './operating_systems'

  # Platform independent means of retrieving the hostname
  def self.hostname
    Socket.gethostbyname(Socket.gethostname).first.downcase
  end
end
