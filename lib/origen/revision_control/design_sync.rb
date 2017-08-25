module Origen
  module RevisionControl
    class DesignSync < Base
      # Check in the contents of the given directory to a remote vault location, meaning a vault location
      # that is not necessarily associated with the current workspace that the given files are in.
      #
      # Anything found in the given directory will be checked in, even files which are not currently under
      # revision control.
      #
      # No attempt will be made to merge the current vault contents with the local data, the local data
      # will always be checked in as latest.
      #
      # A tag can be optionally supplied and if present will be applied to the files post check in.
      #
      # @example
      #
      #   Origen::RevisionControl::DesignSync.remote_check_in("#{Origen.root}/output/j750", vault: "sync://sync-15088:15088/Projects/common_tester_blocks/origen_training/j750", tag: Origen.app.version)
      def self.remote_check_in(dir, options = {})
        options = {
          force: true
        }.merge(options)

        dir = Pathname.new(dir)
        fail "Directory does not exist: #{dir}" unless dir.exist?
        fail "Only directories are supported by remote_check_in, this is not a directory: #{dir}" unless dir.directory?
        fail 'No vault option supplied to remote_check_in!' unless options[:vault]
        scratch = Pathname.new("#{Origen.app.workspace_manager.imports_directory}/design_sync/scratch")
        FileUtils.rm_rf(scratch) if scratch.exist?
        FileUtils.mkdir_p(scratch)
        FileUtils.cp_r("#{dir}/.", scratch)
        remove_dot_syncs!(scratch)
        ds = new(remote: options[:vault], local: scratch)
        ds.checkin(options)
        ds.tag(options[:tag], options) if options[:tag]
        FileUtils.rm_rf(scratch)
      end

      # Import a file to the local workspace from another vault, where the first
      # argument must include the full path to the requested file in the vault. You can optionally
      # supply a destination for where you want the file to end up via the :local option, if no destination
      # is supplied the file will end up in the PWD.
      #
      # This is a DesignSync only API and can be used in cases where you would to fetch a file
      # directly from a vault without setting up an association between a local directory and the
      # vault. i.e. it will not create or modify an existing .SYNC in the local destination directory.
      #
      # ==== Example
      #
      #   # Import this file and save it in RGen.root
      #   file = "sync://sync-15088:15088/Projects/common_tester_blocks/rgen/lib/sys/design_sync.rb"
      #   version = "v0.1.0"   # Version can be any valid DS identifier, e.g. a version number or tag
      #
      #   import(file, version: version, local: RGen.root)
      def self.import(path_to_file_in_vault, options = {})
        options = {
          verbose: true,
          version: 'Latest'
        }.merge(options)
        if options[:verbose]
          puts 'Importing from DesignSync...'
          puts "#{path_to_file_in_vault} #{options[:version]}"
        end
        dir = path_to_file_in_vault.split('/')
        file = dir.pop
        dir = dir.join('/')
        cmd = "import -version #{options[:version]} -force #{dir} #{file}"
        dssc(cmd, verbose: false)
        if Origen.os.windows?
          system("move /Y #{file} #{options[:local]}/.") if options[:local]
        else
          system("mv -f #{file} #{options[:local]}/.") if options[:local]
        end
      end

      # Recursively remove all .SYNC directories from the given directory
      def self.remove_dot_syncs!(dir, options = {})
        dir = Pathname.new(dir)
        fail "Directory does not exist: #{dir}" unless dir.exist?
        fail "Only directories are supported by remove_dot_syncs, this is not a directory: #{dir}" unless dir.directory?
        Dir.glob("#{dir}/**/.SYNC").sort.each do |dot_sync|
          FileUtils.rm_rf(dot_sync)
        end
      end

      def build(options = {})
        checkout(options)
      end

      def checkout(path = nil, options = {})
        paths, options = clean_path(path, options)
        cmd = 'pop'
        cmd += ' -rec -get -uni'
        cmd += ' -force' if options[:force]
        if options[:version]
          cmd += " -version #{prefix_tag(options[:version])}"
        else
          cmd += ' -merge' unless options[:force]
        end
        paths = paths.join(' ')
        dssc("#{cmd} #{paths}", options)
        # Design sync can be funny and even with -get it can leave unwritable files, so let's fix that
        `chmod a+w -R #{paths}`
        paths
      end

      def checkin(path = nil, options = {})
        paths, options = clean_path(path, options)
        cmd = 'ci'
        cmd += ' -rec -keep'
        cmd += ' -skip' if options[:force]
        cmd += ' -new' if options[:unmanaged] || options[:force]
        if options[:comment] && !options[:comment].strip.empty?
          cmd += " -com \"#{options[:comment].strip}\""
        else
          # cmd += ' -nocom' # DO NOT USE nocom option with DesignSync, doesn't always work
          cmd += ' -com None'
        end
        paths = paths.join(' ')
        dssc("#{cmd} #{paths}", options)
        # Make sure the file is still writable
        `chmod a+w -R #{paths}`
        paths
      end

      def changes(dir = nil, options = {})
        paths, options = clean_path(dir, options)
        options = {
          verbose: false
        }.merge(options)

        cmd = 'compare -rec -path -report silent'
        if options[:version]
          cmd += " -selector #{prefix_tag(options[:version])}"
        end
        cmd += " #{paths.first}"

        objects = {
          added: [], removed: [], changed: []
        }
        dssc(cmd, options).each do |line|
          # We need to parse the following data from the output, ignore everything else
          # which will mostly refer to un-managed files.
          #
          # Added since previous version...
          # 1.12                                          First only         source_setup
          # Removed since previous version...
          #                        1.13                   Second only        lib/history
          # Modified since previous version...
          # 1.32                   1.31                   Different versions lib/origen/application.rb
          # Modified since previous version including a local edit...
          # 1.7 (Locally Modified) 1.7                    Different states   lib/origen/commands/rc.rb
          unless line =~ /Unmanaged/
            # http://www.rubular.com/r/GoNYB75upB
            if line =~ /\s*(\S+)\s+First only\s+(\S+)\s*/
              objects[:added] << Regexp.last_match[2]
            # http://www.rubular.com/r/Xvh32Lm4hS
            elsif line =~ /\s*(\S+)\s+Second only\s+(\S+)\s*/
              objects[:removed] << Regexp.last_match[2]
            # http://www.rubular.com/r/tvTHod9Mye
            elsif line =~ /\s*\S+\s+(\(Locally Modified\))?\s*(\S+)\s+Different (versions|states)\s+(\S+)\s*/
              objects[:changed] << Regexp.last_match[4]
            end
          end
        end
        objects[:present] = !objects[:added].empty? || !objects[:removed].empty? || !objects[:changed].empty?
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

        cmd = 'ls -rec -managed -path -report N -modified -format text'
        cmd += " #{paths.first}"

        files = dssc(cmd, options).reject do |item|
          item.strip.empty? ||
          item =~ /^(Name|Directory|---)/
        end
        files.map! do |file|
          file.strip!  # Strip off any whitespace from all objects
          file.sub!(/^#{full_path_prefix}/, '')
          file.sub('|', ':')
          file.sub!(/^/, "#{paths.first}/")
        end
      end

      def unmanaged(dir = nil, options = {})
        paths, options = clean_path(dir, options)
        options = {
          verbose: false
        }.merge(options)
        cmd = 'ls -rec -unmanaged -fullpath -report N -modified -format text'
        cmd += " #{paths.first}"
        files = dssc(cmd, options).reject do |item|
          # removes extraneous lines
          item =~ /^(Name|Directory|---)/ || item.strip.empty?
        end
        files.map! do |file|
          file.strip!  # Strip off any whitespace from all objects
          file.sub!(/^#{full_path_prefix}/, '')
          file.sub('|', ':')
        end
      end

      def diff_cmd(file, version)
        "dssc diff -gui -ver #{prefix_tag(version)} #{file}"
      end

      def tag(id, options = {})
        id = VersionString.new(id)
        id = id.prefixed if id.semantic?
        replace = options[:force] ? '-replace' : ''
        dssc "tag #{id} -rec #{replace} *"
        # Applying this rule recursively seems to cause havoc, so running on its own.
        # This hits any dot files in the root directory, any dot files in sub directories
        # already get hit by the above tag job.
        dssc "tag #{id} #{replace} .*"
      end

      def root
        # This is an expensive operation the way it is currently implemented, so
        # cache the result for future calls
        Origen.app.session.dssc["root-#{local}"] ||= begin
          root = local
          # Create two arrays, one to store the parents and the other to corresponding vaults.
          temp_parent_array = Array.new(0)
          temp_parent_vault_array = Array.new(0)
          resolved = false
          vault = dssc("url vault #{root}").first
          until resolved || root.root?
            parent = root.parent
            # push the current parent into the parent array
            temp_parent_array.push(parent.to_s)
            if File.exist?("#{parent}/.SYNC")
              parent_vault = dssc("url vault #{parent}").first
              # push the current parent_vault into the vault array.
              temp_parent_vault_array.push(parent_vault.to_s)
              if vault.to_s =~ /^#{parent_vault}/ && vault.to_s != parent_vault.to_s
                root = parent
              else
                # Now, check if the parent array has unique values, it should if the DesignSync directory structure is correct.
                if temp_parent_vault_array.uniq.length == temp_parent_vault_array.length
                  resolved = true
                else
                  # To display the file/directory that the user needs to correct the conflict in, pick up the second last element from the parent array.
                  fault_dir = temp_parent_array[-2]
                  fault_dir_name = fault_dir.split('/')[-1]
                  Origen.log.error 'DesignSync returns same vault locations for two directories.'
                  Origen.log.error 'Please resolve the workspace conflicts before continuing'
                  # Un-cache the result so that there is no error in future calls.
                  Origen.app.session.dssc["root-#{local}"] = nil
                  # Remove the .ref symlink from the local directory so that there are no issues in the future call
                  scratch = Pathname.new("#{local}/.ref")
                  FileUtils.rm_rf(scratch) if scratch.exist?
                  abort
                end
              end
            else
              resolved = true
            end
          end
          root
        end
      end

      def current_branch
        dssc("url selector #{local}", verbose: false).first
      end

      private

      def full_path_prefix
        @full_path_prefix ||= begin
          if Origen.running_on_windows?
            'file:///'
          else
            'file://'
          end
        end
      end

      def initialize_local_dir(options = {})
        super
        unless initialized?
          Origen.log.debug "Initializing DSSC workspace at #{local}"
          dssc "setvault #{remote} ."
        end
      end

      def initialized?
        File.exist?("#{local}/.SYNC")
      end

      # Execute a dssc operation, the resultant output is returned in an array
      def self.dssc(command, options = {})
        options = {
          check_errors: true,
          verbose:      true,
          local:        Dir.pwd
        }.merge(options)
        output = []
        if options[:verbose]
          Origen.log.info "dssc #{command}"
          Origen.log.info ''
        end
        Dir.chdir options[:local] do
          Open3.popen2e("dssc #{command}") do |_stdin, stdout_err, wait_thr|
            while line = stdout_err.gets
              Origen.log.info line.strip if options[:verbose]
              # Screen out common redundant output
              unless line =~ /^Logging/ || line == '' ||
                     line =~ /V(\d+\.\d+-\d+|\d.\d+)/ || # Screen out something like "V5.1-1205" or "V6R2010"
                     line =~ /^3DEXPERIENCER\d+x$/ || # Screen out something like '3DEXPERIENCER2016x'
                     line.strip.empty?
                output << line.strip
              end
            end

            exit_status = wait_thr.value
            unless exit_status.success?
              if options[:check_errors]
                fail DesignSyncError, "This command failed: 'dssc #{command}'"
              end
            end
          end
        end
        output
      end

      # Execute a dssc operation, the resultant output is returned in an array
      def dssc(command, options = {})
        options[:local] ||= local
        DesignSync.dssc(command, options)
      end
    end
  end
end
