module Origen
  module RevisionControl
    class Git < Base
      # Returns the origin for the PWD
      def self.origin
        git('remote --verbose', verbose: false).each do |remote|
          if remote =~ /^origin\s+([^\s]+)/
            return Regexp.last_match(1)
          end
        end
        nil
      end

      # Returns the Git version number from the current runtime environment (as a string)
      def self.version
        @version ||= begin
          version = nil
          git('--version', verbose: false).each do |line|
            if line =~ /git version (\d+(\.\d+)+)/
              version = Regexp.last_match(1)
              break
            end
          end
          if version
            version
          else
            Origen.log.warning 'Failed to determine the current Git version, proceeding by assuming version 2.0.0'
            '2.0.0'
          end
        end
      end

      def build(options = {})
        if Dir["#{local}/*"].empty? || options[:force]
          FileUtils.rm_rf(local.to_s)
          # Not using the regular 'git' method here since the local dir doesn't exist to CD into
          system "git clone #{remote} #{local}"
        else
          fail "The requested workspace is not empty: #{local}"
        end
      end

      def checkout(path = nil, options = {})
        paths, options = clean_path(path, options)
        # Pulls latest metadata from server, does not change workspace
        git 'fetch', options

        version = options[:version] || current_branch

        if version == 'HEAD'
          puts "Sorry, but you are not currently on a branch and I don't know which branch you want to checkout"
          puts 'Please supply a branch name as the version to checkout the latest version of it, e.g. origen rc co -v develop'
          exit 1
        end

        if options[:force]
          version = "origin/#{version}" if remote_branch?(version)
          if paths == [local.to_s]
            git "reset --hard #{version}", options
          else
            git 'reset HEAD'
            git 'pull', options
            git "checkout #{version} #{paths.join(' ')}", options
          end
        else
          if paths.size > 1 || paths.first != local.to_s
            fail 'The Git driver does not support partial merge checkout, it has to be the whole workspace'
          end
          git 'reset HEAD'
          res = git 'stash', options
          stashed = !res.any? { |l| l =~ /^No local changes to save/ }
          git 'pull', options
          git "checkout #{version}", options
          if stashed
            result = git 'stash pop', { check_errors: false }.merge(options)
            conflicts = []
            result.each do |line|
              if line =~ /CONFLICT.* (.*)$/
                conflicts << Regexp.last_match(1)
              end
            end
            git 'reset HEAD'
            unless conflicts.empty?
              Origen.log.info ''
              Origen.log.error 'Your local changes could not automatically merged into the following files, open them to fix the conflicts:'
              conflicts.each do |conflict|
                Origen.log.error "  #{conflict}"
              end
            end
          end
        end
        paths
      end

      def checkin(path = nil, options = {})
        paths, options = clean_path(path, options)
        # Can't check in unless we have the latest
        if options[:force] && !options[:initial]
          # Locally check in the given files
          checkin(paths.join(' '), no_push: true, verbose: false, comment: options[:comment])
          local_rev = current_commit(short: false)
          # Pull latest
          checkout
          # Restore the given files to our previous version
          # Errors are ignored here since this can fail if the given file didn't exist until now,
          # in that case we already implicitly have the previous version
          git("checkout #{local_rev} -- #{paths.join(' ')}", check_errors: false)
          # Then proceed with checking them in as latest
        else
          checkout unless options[:initial]
        end
        cmd = 'add'
        if options[:unmanaged]
          cmd += ' -A'
        else
          cmd += ' -u' unless options[:unmanaged]
        end
        cmd += " #{paths.join(' ')}"
        git cmd, options
        if changes_pending_commit?
          cmd = 'commit'
          if options[:comment] && !options[:comment].strip.empty?
            cmd += " -m \"#{options[:comment].strip}\""
          else
            cmd += " -m \"No comment!\""
          end
          if options[:author]
            if options[:author].respond_to?(:name_and_email)
              author =  options[:author].name_and_email
            else
              author = "#{options[:author]} <>"
            end
            cmd += " --author=\"#{author}\""
          end
          if options[:time]
            cmd += " --date=\"#{options[:time].strftime('%a %b %e %H:%M:%S %Y %z')}\""
          end
          git cmd, options
        end
        unless options[:no_push]
          cmd = "push origin #{current_branch}"
          cmd += ' -u' if options[:initial]
          git cmd
        end
        paths
      end

      # Returns true if the current user can checkin to the given repo (means has permission
      # to push in Git terms)
      def can_checkin?
        # dry run attempting to create a new remote branch named OrigenWritePermissionsTest
        git('push --dry-run origin origin:refs/heads/OrigenWritePermissionsTest', verbose: false)
        true
      rescue
        false
      end

      def changes(dir = nil, options = {})
        paths, options = clean_path(dir, options)
        options = {
          verbose: false
        }.merge(options)
        # Pulls latest metadata from server, does not change workspace
        git 'fetch', options

        version = options[:version] || 'HEAD'
        objects = {}

        objects[:added]   = git("diff --name-only --diff-filter=A #{version} #{paths.first}", options).map(&:strip)
        objects[:removed] = git("diff --name-only --diff-filter=D #{version} #{paths.first}", options).map(&:strip)
        objects[:changed] = git("diff --name-only --diff-filter=M #{version} #{paths.first}", options).map(&:strip)

        objects[:present] = !objects[:added].empty? || !objects[:removed].empty? || !objects[:changed].empty?
        # Return full paths
        objects[:added].map! { |i| "#{paths.first}/" + i }
        objects[:removed].map! { |i| "#{paths.first}/" + i }
        objects[:changed].map! { |i| "#{paths.first}/" + i }
        objects
      end

      def local_modifications(dir = nil, options = {})
        paths, options = clean_path(dir, options)
        options = {
          verbose: false
        }.merge(options)

        cmd = 'diff --name-only'
        dir = " #{paths.first}"
        unstaged = git(cmd + dir, options).map(&:strip)
        staged = git(cmd + ' --cached' + dir, options).map(&:strip)
        unstaged + staged
      end

      def unmanaged(dir = nil, options = {})
        paths, options = clean_path(dir, options)
        options = {
          verbose: false
        }.merge(options)
        cmd = "ls-files #{paths.first} --exclude-standard --others"
        git(cmd, options).map(&:strip)
      end

      def diff_cmd(file, version = nil)
        if version
          "git difftool --tool tkdiff -y #{prefix_tag(version)} #{file}"
        else
          "git difftool --tool tkdiff -y #{file}"
        end
      end

      def tag(id, options = {})
        id = VersionString.new(id)
        id = id.prefixed if id.semantic?
        if options[:comment]
          git "tag -a #{id} -m \"#{options[:comment]}\""
        else
          git "tag #{id}"
        end
        git "push origin #{id}"
      end

      def root
        Pathname.new(git('rev-parse --show-toplevel', verbose: false).first.strip)
      end

      def current_branch
        git('rev-parse --abbrev-ref HEAD', verbose: false).first
      end

      def current_commit(options = {})
        options = {
          short: true
        }.merge(options)
        commit = git('rev-parse HEAD', verbose: false).first
        if options[:short]
          commit[0, 11]
        else
          commit
        end
      end

      # Returns true if the given tag already exists
      def tag_exists?(tag)
        git('fetch', verbose: false) unless @all_tags_fetched
        @all_tags_fetched = true
        git('tag', verbose: false).include?(tag.to_s)
      end

      # Returns true if the given string matches a branch name in the remote repo
      #   Origen.app.rc.remote_branch?("master")                 # => true
      #   Origen.app.rc.remote_branch?("feature/exists")         # => true
      #   Origen.app.rc.remote_branch?("feature/does_not_exist") # => false
      def remote_branch?(str)
        # Github doesn't like the ssh:// for this command, whereas Stash seems
        # to require it.
        if github?
          rem = remote_without_protocol
        else
          rem = remote
        end
        # check if matches 40 digit hex string followed by branch name
        git("ls-remote --heads #{remote} #{str}", verbose: false).any? do |line|
          line =~ /^[0-9a-f]{40}\s+[a-zA-Z]/
        end
      end

      def initialized?(options = {})
        @hierarchy_searched ||= begin
          path = @local.dup
          until path.root? || File.exist?("#{local}/.git")
            if File.exist?("#{path}/.git")
              if options[:allow_local_adjustment]
                @local = path
              else
                fail "Requested local repository #{local} is within existing local repository #{path}"
              end
            else
              path = path.parent
            end
          end
          true
        end
        File.exist?("#{local}/.git") &&
          git('remote -v', verbose: false).any? { |r| r =~ /#{remote_without_protocol_and_user}/ || r =~ /#{remote_without_protocol_and_user.to_s.gsub(':', "\/")}/ } &&
          !git('status', verbose: false).any? { |l| l =~ /^#? ?(Initial commit|No commits yet)$/ }
      end

      # Delete everything in the given directory, or the whole repo
      def delete_all(dir = nil, options = {})
        paths, options = clean_path(dir, options)
        files = git("ls-files #{paths.first}")
        FileUtils.rm_f files
      end

      # A class method is provided to fetch the user name since it is useful to have access
      # to this when outside of an application workspace, e.g. when creating a new app
      def self.user_name
        git('config user.name', verbose: false).first
      rescue
        nil
      end

      # A class method is provided to fetch the user email since it is useful to have access
      # to this when outside of an application workspace, e.g. when creating a new app
      def self.user_email
        git('config user.email', verbose: false).first
      rescue
        nil
      end

      def user_name
        self.class.user_name
      end

      def user_email
        self.class.user_email
      end

      # Returns true if the remote points to a github url
      def github?
        !!(remote.to_s =~ /github.com/)
      end

      private

      def remote_without_protocol
        Pathname.new(remote.sub(/^.*:\/\//, ''))
      end

      def remote_without_protocol_and_user
        Pathname.new(remote_without_protocol.to_s.sub(/^.*@/, ''))
      end

      def create_gitignore
        c = Origen::Generator::Compiler.new
        c.compile "#{Origen.top}/templates/git/gitignore.erb",
                  output_directory:  local,
                  quiet:             true,
                  check_for_changes: false
        FileUtils.mv "#{local}/gitignore", "#{local}/.gitignore"
      end

      def changes_pending_commit?
        !(git('status --verbose', verbose: false).last =~ /^(no changes|nothing to commit|nothing added to commit but untracked files present)/)
      end

      def initialize_local_dir(options = {})
        return if options[:build_method] == :clone
        super
        unless initialized?(options)
          Origen.log.debug "Initializing Git workspace at #{local}"
          git 'init'
          git 'remote remove origin', verbose: false, check_errors: false
          git "remote add origin #{remote}", check_errors: false
        end
      end

      def git(command, options = {})
        options[:local] = local
        self.class.git(command, options)
      end

      # Execute a git operation, the resultant output is returned in an array
      def self.git(command, options = {})
        options = {
          check_errors: true,
          verbose:      true
        }.merge(options)
        output = []
        if options[:verbose]
          Origen.log.info "git #{command}"
          Origen.log.info ''
        end
        chdir options[:local] do
          Open3.popen2e("git #{command}") do |_stdin, stdout_err, wait_thr|
            while line = stdout_err.gets
              Origen.log.info line.strip if options[:verbose]
              unless line.strip.empty?
                output << line.strip
              end
            end

            exit_status = wait_thr.value
            unless exit_status.success?
              if options[:check_errors]
                if output.any? { |l| l =~ /Not a git repository/ }
                  fail RevisionControlUninitializedError
                else
                  fail GitError, "This command failed: 'git #{command}'"
                end
              end
            end
          end
        end
        output
      end

      def self.chdir(dir)
        if dir
          Dir.chdir dir do
            yield
          end
        else
          yield
        end
      end
    end
  end
end
