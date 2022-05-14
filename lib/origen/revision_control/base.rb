require 'open3'
module Origen
  module RevisionControl
    # Base class of all revision control system drivers,
    # all drivers should support the API methods defined here.
    #
    # Each instance of this class represents the concept of mapping a local directory to
    # a remote repository.
    #
    # Origen.app.rc will return an instance of this class for the revision control system used
    # by the current application, the :local attribute will be automatically set to
    # Origen.root and the :remote attribute will be set per the revision control attributes
    # defined in config/application.rb.
    class Base
      # Returns a pointer to the remote location (a Pathname object)
      attr_reader :remote
      # Returns a pointer to the local location (a Pathname object)
      attr_reader :local
      # Method to use by Origen::RemoteManager to handle fetching a remote file
      attr_reader :remotes_method

      # rubocop:disable Lint/UnusedMethodArgument

      # All revision control instances represent a remote server mapping
      # to a local directory, :remote and :local options are required
      def initialize(options = {})
        unless options[:remote] && options[:local]
          fail ':remote and :local options must be supplied when instantiating a new RevisionControl object'
        end

        @remote = Pathname.new(options[:remote])
        @local = Pathname.new(options[:local]).expand_path
        @remotes_method = :checkout
        initialize_local_dir(options)
      end

      # Build the local workspace for the first time.
      #
      # This is roughly equivalent to running the checkout command, but should be used in the case where
      # the local workspace is being setup for the first time.
      def build(options = {})
        fail "The #{self.class} driver does not support the build method!"
      end

      # Checkout the given file or directory, it returns a path to the local file.
      #
      # The path argument is optional and when not supplied the entire directory will be checked out.
      #
      # @param [String, Pathname] path
      #   The path to the remote item to checkout, this can be a pointer to a file or directory
      #   and it can either be a relative path or absolute path to either the local or remote locations.
      #   Multiple values can be supplied and should be separated by a space.
      # @param [Hash] options Options to customize the operation
      # @option options [Boolean] :force (false) Force overwrite of any existing local copy
      # @option options [String] :version (nil) A specific version to checkout, will get latest if
      #   not supplied
      # @option options [Boolean] :verbose (true) When true will show the command being executed and
      #   the raw output from the underlying revision control tool. When false will show nothing, but
      #   will still raise an error if the underlying command fails.
      def checkout(path = nil, options = {})
        fail "The #{self.class} driver does not support the checkout method!"
      end

      # Checkin the given file or directory, it returns a path to the local file.
      #
      # The path argument is optional and when not supplied the entire directory will be checked in.
      #
      # @param [String, Pathname] path
      #   The path to the remote item to checkout, this can be a pointer to a file or directory
      #   and it can either be a relative path or absolute path to either the local or remote locations.
      #   Multiple values can be supplied and should be separated by a space.
      # @param [Hash] options Options to customize the operation
      # @option options [Boolean] :force (false) Force overwrite of any newer version of the file that may
      #   exist, i.e. force checkin the current version to become the latest.
      # @option options [Boolean] :unmanaged (false) Include files matching the given path that are not currently
      #   managed by the revision control system.
      # @option options [Boolean] :comment (nil) Optionally supply a checkin comment.
      # @option options [Boolean] :verbose (true) When true will show the command being executed and
      #   the raw output from the underlying revision control tool. When false will show nothing, but
      #   will still raise an error if the underlying command fails.
      def checkin(path = nil, options = {})
        fail "The #{self.class} driver does not support the checkin method!"
      end

      # Returns a hash containing the list of files that have changes compared to the given tag
      # or compared to the latest version (on the server).
      #
      #   {
      #     :added => [],           # Paths to files that have been added since the previous tag
      #     :removed => [],         # Paths to files that have been removed since the previous tag
      #     :changed => [],         # Paths to files that have changed since the previous tag
      #     :present => true/false, # Convenience attribute for the caller to check if there are any changes, when
      #                             # true at least one of the other arrays will contain a value
      #   }
      #
      # The dir argument is optional and when not supplied the entire directory will be checked for
      # changes.
      #
      # Note that added files only refers to those files which have been checked into revision control
      # since the compared to version, it does not refer to unmanaged files in the workspace.
      # Use the unmanaged method to get a list of those.
      #
      # Note also that while a file is considered added or removed depends on the chronological
      # relationship between the current version (the user's workspace) and the reference version.
      # If the reference version is older than the current version (i.e. an earlier tag), then an added
      # file means a file that the current version has and the reference (previous) version did not have.
      #
      # However if the reference version is newer than the current version (e.g. when comparing to a newer
      # tag or the latest version on the server), then an added file means a file that the current
      # version does not have and which has been added in a newer version of the remote directory.
      #
      # @param [String, Pathname] dir
      #   The path to a sub-directory to check for changes, it can either be a relative path or an
      #   absolute path to either the local or remote locations.
      # @param [Hash] options Options to customize the operation
      # @option options [String] :version (nil) A specific version to compare against, will compare to
      #   latest if not supplied
      # @option options [Boolean] :verbose (false) When true will show the command being executed and
      #   the raw output from the underlying revision control tool. When false will show nothing. False
      #   is the default as with this command the user is more concerned with seeing the organized
      #   summary that is returned from this method.
      def changes(dir = nil, options = {})
        fail "The #{self.class} driver does not support the changes method!"
      end

      # Returns an array containing the files that have un-committed local changes.
      #
      # The dir argument is optional and when not supplied the entire directory will be checked for
      # changes.
      #
      # @param [String, Pathname] dir
      #   The path to a sub-directory to check for changes, it can either be a relative path or an
      #   absolute path to either the local or remote locations.
      # @param [Hash] options Options to customize the operation
      # @option options [Boolean] :verbose (false) When true will show the command being executed and
      #   the raw output from the underlying revision control tool. When false will show nothing. False
      #   is the default as with this command the user is more concerned with seeing the organized
      #   summary that is returned from this method.
      def local_modifications(dir = nil, options = {})
        fail "The #{self.class} driver does not support the local_modifications method!"
      end

      # Returns an array containing the list of files that are present in the given directory but
      # which are not managed by the revision control system.
      #
      # The dir argument is optional and when not supplied the entire directory will be checked for
      # unmanaged files.
      #
      # @param [String, Pathname] dir
      #   The path to a sub-directory to check for unmanaged files, it can either be a relative path or an
      #   absolute path to either the local or remote locations.
      # @param [Hash] options Options to customize the operation
      # @option options [Boolean] :verbose (false) When true will show the command being executed and
      #   the raw output from the underlying revision control tool. When false will show nothing. False
      #   is the default as with this command the user is more concerned with seeing the organized
      #   summary that is returned from this method.
      def unmanaged(dir = nil, options = {})
        fail "The #{self.class} driver does not support the unmanaged method!"
      end

      # Returns the command the user must run to execute a diff of the current version of the given file
      # against the given version of it.
      #
      # @param [String, Pathname] file
      #   The local path to the file to be compared.
      # @param [String] version
      #   The version of the file to compare to.
      def diff_cmd(file, version)
        fail "The #{self.class} driver does not support the diff_cmd method!"
      end

      # Returns what is considered to be the top-level root directory by the revision control system.
      #
      # In the case of an application's revision controller (returned by Origen.app.rc) this method will often
      # return the same directory as Origen.root. However in some cases an application owner may choose to store
      # their application in a sub directory of a larger project entity that is revision controlled. In that
      # case Origen.root will return the sub directory and this method will return the top-level directory
      # of the wider project.
      def root
        fail "The #{self.class} driver does not support the root method!"
      end

      # Returns the name of the current branch in the local workspace
      def current_branch
        fail "The #{self.class} driver does not support the current_branch method!"
      end

      # Returns true if the revision controller object uses Design Sync
      def dssc?
        is_a?(DesignSync)
      end
      alias_method :design_sync?, :dssc?

      # Returns true if the revision controller object uses Git
      def git?
        is_a?(Git) # :-)
      end

      # Returns true if the revision controller object uses Perforce
      def p4?
        is_a?(Perforce)
      end
      alias_method :perforce?, :p4?

      # Returns true if the revision controller object uses Subversion
      def svn?
        is_a?(Subversion) # :-)
      end
      alias_method :subversion?, :svn?

      # rubocop:enable Lint/UnusedMethodArgument

      private

      def clean_path(path = nil, options = {})
        path, options = nil, path if path.is_a?(Hash)
        if path
          paths = to_local(path)
        else
          paths = [local.to_s]
        end
        [paths, options]
      end

      # Converts a given path string to files/directories to an array of absolute paths to the
      # resources within the local directory.
      # The input can either contain a path to the local directory, or the remote.
      #
      # @example
      #   to_local("config/application.rb sync://sync-15088:15088/Projects/common_tester_blocks/origen/lib")
      #     # => ["/home/r49409/origen/config/application.rb", "/home/r49409/origen/lib"]
      def to_local(path)
        local_abs_paths = []
        path.to_s.split(/\s+/).each do |p|
          if p =~ /^#{remote}/
            p.sub!(/^#{remote}/, '')
            p.slice!(0) if p =~ /^\//
            p = "#{local}/#{p}"
          else
            if Pathname.new(p).absolute?
              # No action required
            else
              p = "#{local}/#{p}"
            end
          end
          local_abs_paths << p
        end
        local_abs_paths
      end

      # If the supplied tag looks like a semantic version number, then make sure it has the
      # 'v' prefix
      def prefix_tag(tag)
        tag = Origen::VersionString.new(tag)
        if tag.semantic?
          tag.prefixed
        else
          tag
        end
      end

      def initialize_local_dir(options = {})
        FileUtils.mkdir_p(local.to_s) unless local.exist?
      end
    end
  end
end
