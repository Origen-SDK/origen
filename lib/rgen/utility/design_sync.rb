module RGen
  module Utility
    # Ruby API to interface with Design Sync
    class DesignSync
      # Tag the target which is an absolute path to a file or directory.
      #
      # ==== Options
      #
      # * :rec      # Recursive, false by default
      # * :delete   # Delete the given tag from the target, false by default
      # * :replace  # Replace any existing version of the given tag, false by default
      # * :exclude  # Supply filenames to exclude or wildcard, e.g. "*.lst,*.S19"
      #
      # ==== Example
      #
      #   tag(RGen.root, "my_release_001", :rec => true)
      #   tag("#{RGen.root}/top/top_block.rb", "my_release_001")
      def tag(target, tag, options = {})
        options = { rec:     false,   # Set true to tag recursively
                    delete:  false,
                    replace: false
        }.merge(options)
        cmd = "dssc tag #{tag} #{exclude(options)} #{options[:replace] ? '-replace' : ''} #{rec(options)} #{options[:delete] ? '-delete' : ''} #{target}"
        if options[:debug]
          puts '**** DesignSync Debug ****'
          puts cmd
        else
          system(cmd)
        end
      end

      # Import a file to the local workspace from another vault, where the vault
      # argument must include the full path to the requested file. You can optionally
      # supply a destination for where you want the file to end up, if no destination
      # is supplied the file will end up in the PWD.
      #
      # ==== Example
      #
      #   # Import this file and save it in RGen.root
      #   file = "design_sync.rb"
      #   vault = "sync://sync-15088:15088/Projects/common_tester_blocks/rgen/lib/sys"
      #   version = "v0.1.0"   # Version can be any valid DS identifier, e.g. a version number or tag
      #
      #   import(file, vault, version, RGen.root)
      def import(file, vault, version, destination = false)
        puts 'Importing from DesignSync...'
        puts "#{vault}/#{file} #{version}"
        unless sys("dssc import -version #{version} -force #{vault} #{file}")[0] =~ /Success/
          fail "Error importing #{file} from Design Sync"
        end
        if RGen.running_on_windows?
          sys("move /Y #{file} #{destination}/.") if destination
        else
          sys("mv -f #{file} #{destination}/.") if destination
        end
      end

      # Check out a specific target which should be an absolute path to the target file, or
      # wildcard expression.
      #
      # ==== Options:
      #
      # * :rec        # Do a recursive checkout, false by default
      # * :lock       # Check out with a lock (overrides get option due to DesignSync get/lock incompatibility)
      # * :version    # Specific tag or version number, will get latest by default
      # * :force      # Force check out, false by default
      # * :verbose    # Display output to terminal, false by default
      # * :get        # Fetch locally editable copies, true by default (unless lock is set)
      #
      # ==== Example
      #
      #   # Checkout everything in RGen.root
      #   check_out("#{RGen.root}/*", :rec => true)
      def check_out(target, options = {})
        options = {
          get: true
        }.merge(options)
        cmd = "dssc co #{rec(options)} #{get(options)} #{loc(options)} #{ver(options)} #{force(options)} -nocomment #{target}"
        launch(cmd, options[:verbose])
      end

      # Check in a specific target which should be an absolute path to the target file, or
      # wildcard expression.
      #
      # ==== Options:
      #
      # * :rec        # Do a recursive check-in, false by default
      # * :comment    # Supply a comment to go with the check-in
      # * :new        # Allow check in of new files (i.e. add the file to revision control)
      # * :verbose    # Display output to terminal, false by default
      # * :skip       # Allow check in to skip over a newer version of the file if it exists
      # * :keep       # Keep editable copy of the files post check-in, false by default
      #
      # ==== Example
      #
      #   # Check-in everything in RGen.root
      #   check_in("#{RGen.root}/*", :rec => true, :com => "Periodic checkin, still in development")
      def check_in(target, options = {})
        options = {
          keep:    true
        }.merge(options)
        # FYI: for debug use '-dryrun' option to 'dssc ci' command
        cmd = "dssc ci #{keep(options)} #{rec(options)} #{new(options)} #{com(options)} #{branch(options)} #{options[:skip] ? '-skip' : ''} #{target}"
        launch(cmd, options[:verbose])
      end

      # Check in the contents of the given directory to a remote vault location, that is a vault location
      # that is not associated with the workspace that the given files are in.
      #
      # Anything found in the given directory will be checked in, even files which are not currently under
      # revision control.
      #
      # No attempt will be made to merge the current vault contents with the local data, the local data
      # will always be checked in as lastest.
      #
      # A tag can be optionally supplied and if present will be applied to the files post check in.
      #
      # @example
      #
      #   ds.remote_check_in("#{RGen.root}/output/j750", :vault => "sync://sync-15088:15088/Projects/common_tester_blocks/rgen_training/j750", :tag => RGen.app.version)
      def remote_check_in(dir, options = {})
        RGen.deprecate 'Use RGen::RevisionControl::DesignSync.remote_check_in instead'
        options = {
          verbose: true,
          rec:     true,
          keep:    true,
          new:     true,
          skip:    true,
          replace: true
        }.merge(options)

        dir = Pathname.new(dir)
        fail "Directory does not exist: #{dir}" unless dir.exist?
        fail "Only directories are supported by remote_check_in, this is not a directory: #{dir}" unless dir.directory?
        fail 'No vault option supplied to remote_check_in!' unless options[:vault]
        scratch = Pathname.new("#{RGen.app.workspace_manager.imports_directory}/design_sync/scratch")
        FileUtils.rm_rf(scratch) if scratch.exist?
        FileUtils.mkdir_p(scratch)
        FileUtils.cp_r("#{dir}/.", scratch)
        remove_dot_syncs!(scratch)
        launch("dssc setvault #{options[:vault]} #{scratch}", options[:verbose])
        check_in(scratch, options)
        tag(scratch, options[:tag], options) if options[:tag]
        FileUtils.rm_rf(scratch)
      end

      # Recursively remove all .SYNC directories from the given directory
      def remove_dot_syncs!(dir, _options = {})
        RGen.deprecate 'Use RGen::RevisionControl::DesignSync.remove_dot_syncs! instead'
        dir = Pathname.new(dir)
        fail "Directory does not exist: #{dir}" unless dir.exist?
        fail "Only directories are supported by remove_dot_syncs, this is not a directory: #{dir}" unless dir.directory?
        Dir.glob("#{dir}/**/.SYNC").sort.each do |dot_sync|
          FileUtils.rm_rf(dot_sync)
        end
      end

      # Cancel a checkout of a specific target which should be an absolute path to the target file,
      # or wildcard expression
      #
      # ==== Options:
      #
      # * :rec        # Do a recursive cancel, false by default
      # * :force      # Force cancel (overwrite local edits), false by default
      # * :exclude    # Supply filenames to exclude or wildcard, e.g. "*.lst,*.S19"
      # * :keep       # Keep editable copy of the files post cancel, false by default
      #
      # ==== Example
      #
      #   # Cancel every checkout in RGen.root
      #   cancel("#{RGen.root}/*", :rec => true, :force => true)
      def cancel(_target, options = {})
        # Note "-verbose" is not a valid option for dssc cancel
        cmd = "dssc cancel #{keep(options)} #{rec(options)} #{force(options)} #{exclude(options)}"
        launch(cmd)
      end

      # Almost the same as DesignSync#check_out but accepts some different options.
      #
      # ==== Options:
      #
      # * :rec        # Do a recursive populate, false by default
      # * :version    # Specific tag or version number, will get latest by default
      # * :force      # Force populate (overwrite local edits), false by default
      # * :unify      # Unify the workspace (remove any retired files you currently have checked out)
      # * :exclude    # Supply filenames to exclude or wildcard, e.g. "*.lst,*.S19"
      # * :verbose    # Display output to terminal, false by default
      # * :get        # Fetch locally editable copies, true by default
      # * :merge      # Merge local edits into latest files, false by default
      def populate(target, options = {})
        options = { unify:       true,
                    incremental: false,
                    replace:     false,
                    get:         true,
                    merge:       false
                  }.merge(options)
        inc = options[:incremental] ? '-inc' : ''
        replace = options[:replace] ? '-replace' : ''
        cmd = "dssc pop #{inc} #{replace} #{rec(options)} #{force(options)} #{merge(options)} #{get(options)} #{ver(options)} #{uni(options)} #{exclude(options)} #{target}"
        successful = launch(cmd, options[:verbose])
        unless successful
          fail "Something went wrong when populating #{target} from DesignSync!"
        end
      end

      # Check if the supplied directory has any modified objects, will reflect the result from the
      # last call unless :refresh => true. Returns true or false.
      # See DesignSync#modified_objects for available options.
      #
      # ==== Example
      #
      #   modified_objects?                   # Takes a while to run while the workspace is queried
      #   modified_objects?                   # Runs very quickly and returns the cached answer
      #   modified_objects?(:refresh => true) # Takes a while to run while the workspace is queried
      def modified_objects?(*args)
        modified_objects(*args).size > 0
      end

      # Returns the selector for the given object, which should be an absolute path to a
      # file or directory
      def selector(target)
        sys("dssc url selector #{target}")[0]
      end

      # Returns an array of paths to modified files, caches result for performance, set :refresh => true
      # to clear cache. The target should be an absolute path to the directory you want to query.
      #
      # ==== Options:
      #
      # * :rec        # Do a recursive search, false by default
      # * :exclude    # Supply filenames to exclude or wildcard, e.g. "*.lst,*.S19"
      # * :refresh    # Force a new search, false by default
      #
      # ==== Example
      #
      #   # Get all modified files in my project workspace
      #   files = modified_objects(RGen.root, :rec => true)
      #
      # NOTE: -unmanaged and -managed are mutually exclusive, specifying both does neither!
      #       -unmanaged : show only objects not under revision control
      #       -managed   : show only objects under revision control
      #       -modified  : show locally modified files in workspace (includes unmanaged objects)
      #       -changed   : shows not up-to-date files.  Includes both locally modified and newer verions in vault.
      #                    Overrides -modified.

      def modified_objects(target, options = {})
        options = {
          managed: true,  # by default handle managed (to permit for unmanaged case)
          remote:  false,  # includes files possibly modified by others in repository
        }.merge(options)
        # The result of this method is cached for future calls (method called twice actually)
        @objects = nil if options[:refresh]
        @needs_update_objects = nil if options[:refresh]

        if options[:remote]
          return @needs_update_objects if @needs_update_objects
        else
          return @objects if @objects
        end

        # Since DesignSync does not supply an option to only list files that need update (!), have to run with
        # -changed option then again without and difference the 2 arrays!
        if options[:remote]
          all_objects = sys("dssc ls #{rec(options)} #{exclude(options)} #{managed(options)} #{dssc_path(options)} -report N -modified #{unmanaged(options)} -changed -format text #{target}").reject do |item|
            # removes extraneous lines
            item =~ /^(Name|Directory|---)/
          end
          all_objects.map! do |object|
            object.strip!  # Strip off any whitespace from all objects
            object.sub!(/^#{full_path_prefix}/, '')
            object.sub('|', ':')
          end
        end

        @objects = sys("dssc ls #{rec(options)} #{exclude(options)} #{managed(options)} #{dssc_path(options)} -report N -modified #{unmanaged(options)} -format text #{target}").reject do |item|
          # removes extraneous lines
          item =~ /^(Name|Directory|---)/
        end
        @objects.map! do |object|
          object.strip!  # Strip off any whitespace from all objects
          object.sub!(/^#{full_path_prefix}/, '')
          object.sub('|', ':')
        end

        # Now difference the lists if remote desired
        if options[:remote]
          return @needs_update_objects = all_objects - @objects
        else
          return @objects
        end
      end

      def full_path_prefix
        @full_path_prefix ||= begin
          if RGen.running_on_windows?
            'file:///'
          else
            'file://'
          end
        end
      end

      # Check if the supplied directory has any changed objects vs the previous tag
      # See DesignSync#changed_objects for available options.
      def changed_objects?(*args)
        objects = changed_objects(*args)
        objects[:added].size > 0 || objects[:removed].size > 0 || objects[:changed].size > 0
      end

      # Returns a hash containing files that have changed vs. the previous tag, this is
      # organized as follows:
      #
      #   {
      #     :added => [],    # Paths to files that have been added since the previous tag
      #     :removed => [],  # Paths to files that have been removed since the previous tag
      #     :changed => [],  # Paths to files that have changed since the previous tag
      #   }
      def changed_objects(target, previous_tag, options = {})
        options = {
        }.merge(options)
        # We need to parse the following data from the output, ignore everything else
        # which will mostly refer to un-managed files.
        #
        # Added since previous version...
        # 1.12                                          First only         source_setup
        # Removed since previous version...
        #                        1.13                   Second only        lib/history
        # Modified since previous version...
        # 1.32                   1.31                   Different versions lib/rgen/application.rb
        # Modified since previous version including a local edit...
        # 1.7 (Locally Modified) 1.7                    Different states   lib/rgen/commands/rc.rb
        objects = {
          added: [], removed: [], changed: []
        }
        sys("dssc compare -rec -path -report silent -selector #{previous_tag} #{target}").each do |line|
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
        objects
      end

      def diff_cmd(options = {})
        if options[:version]
          "dssc diff -gui -ver #{options[:version]}"
        else
          'dssc diff -gui'
        end
      end

      # Returns true if the given file is known to Design Sync
      #
      # ==== Example
      #
      #   managed_by_design_sync?("#{RGen.root}/config/application.rb")
      def managed_by_design_sync?(path, _options = {})
        res = sys "dssc url vault #{path}"
        if res.empty?
          false
        else
          if res.first =~ /^file:/ || res.first =~ /There is no object with that name/
            false
          else
            true
          end
        end
      end

      # Will recursively move back up the directory tree from the given
      # directory and return the first one that is not part of a Design Sync
      # workspace.
      #
      # The supplied pathname should be an absolute Pathname instance.
      def container_directory(pathname)
        if managed_by_design_sync?(pathname)
          container_directory(pathname.parent)
        else
          pathname
        end
      end

      # Initializes the given directory with the given vault reference
      def initialize_dir(dir, vault)
        Dir.chdir dir do
          sys "dssc setvault #{vault} ."
        end
      end

      # Returns the vault reference to give local file or directory
      def vault(file_or_dir)
        (sys "dssc url vault #{file_or_dir}").first
      end

      private

      # This will return true if the command has run successfully without errors
      def launch(cmd, verbose = false) # :nodoc:
        if verbose
          $stdout.sync = true
          puts cmd
          system cmd
        else
          `#{cmd}`
          $CHILD_STATUS.success?
        end
      end

      # Make a sys call, returning the output in an array
      def sys(call) # :nodoc:
        output = `#{call}`.split("\n")
        # Screen out some common redundant DS output before handing back
        output.reject do |item|
          item =~ /^Logging/ || item == '' ||
            item =~ /V(\d+\.\d+-\d+|\d.\d+)/  # Screen out something like "V5.1-1205" or "V6R2010"
        end
      end

      def exclude(options) # :nodoc:
        options[:exclude] ? "-exclude '#{options[:exclude]}'" : ''
      end

      def rec(options) # :nodoc:
        options[:rec] ? '-rec' : ''
      end

      def force(options) # :nodoc:
        options[:force] ? '-force' : ''
      end

      def uni(options) # :nodoc:
        (options[:uni] || options[:unify]) ? '-uni' : ''
      end

      def get(options) # :nodoc:
        # lock option overrides get option
        # due to incompatibility in DesignSync
        if !(options[:lock] || options[:loc])
          options[:get] ? '-get' : ''
        else
          ''
        end
      end

      def loc(options) # :nodoc:
        (options[:lock] || options[:loc]) ? '-loc' : '-get'
      end

      def keep(options) # :nodoc:
        (options[:keep]) ? '-keep' : ''
      end

      def merge(options) # :nodoc:
        (options[:merge]) ? '-merge' : ''
      end

      def ver(options) # :nodoc:
        options[:version] ? "-ver #{options[:version]}" : ''
      end

      def branch(options) # :nodoc:
        options[:branch] ? "-branch #{options[:branch]}" : ''
      end

      def new(options) # :nodoc:
        options[:new] ? '-new' : ''
      end

      def com(options) # :nodoc:
        options[:comment] ? "-com \"#{options[:comment]}\"" : '-comment /null'
      end

      def unmanaged(options) # :nodoc:
        options[:unmanaged] ? '-unmanaged' : ''
      end

      def managed(options) # :nodoc:
        options[:managed] ? '-managed' : ''
      end

      def dssc_path(options) # :nodoc:
        options[:fullpath] ? '-fullpath' : '-path'
      end
    end
  end
end
