require 'optparse'

include Origen::Utility::InputCapture

def _unmanaged_files
  unmanaged_files = Origen::RevisionControl::IGNORE_FILES
  unmanaged_files += config.unmanaged_files || []
  unmanaged_files += Origen.import_manager.all_symlinks || []

  # If the given files are not full paths then prefix with Origen.root, unless they
  # are wildcards
  unmanaged_files.map do |f|
    if f =~ /\*/ || Pathname.new(f).absolute?
      f
    else
      "#{Origen.root}/#{f}"
    end
  end
end

def _unmanaged_dirs
  # List of unmanaged files and directories for an Origen workspace
  unmanaged_dirs = Origen::RevisionControl::IGNORE_DIRS
  unmanaged_dirs += config.unmanaged_dirs || []

  # If the given dirs are not full paths then prefix with Origen.root
  unmanaged_dirs.map do |d|
    if Pathname.new(d).absolute?
      d
    else
      "#{Origen.root}/#{d}"
    end
  end
end

def workspace_dirs
  "#{Origen.root} " + Origen.app.config.external_app_dirs.join(' ')
end

module Origen
  options = {}

  Origen.load_application

  # App options are options that the application can supply to extend this command
  app_options = @application_options || []
  opt_parser = OptionParser.new do |opts|
    opts.banner = <<-EOT
Origen Revision Control commands.

This command set provides a universal command line interface for working with a revision control
system, thereby providing the following benefits to the user:

  * Intimate knowledge of how the underlying revision control system works is not required,
    the command maintainers will ensure that you are using it in an efficient and correct way.
  * The workflow remains the same regardless of what underlying revision control tool is used.

Currently supported backend systems are:

  * Design Sync

Usage: origen rc CMD [options]

Quickstart examples:

  Checkout
  --------
  origen rc co            # Checkout the latest version of the application, local edits will be merged
  origen rc co -v v1.2.3  # As above but a specific version
  origen rc co -f         # As above but force overwrite of local edits
  origen rc co file.txt   # As above but on a specific file or directory, -v and -f will work to

  Checkin
  -------
  origen rc ci            # Check in the application
  origen rc ci --unman    # As above but also include files that are currently unmanaged
  origen rc ci file.txt   # Check in a specific file
  origen rc new file.txt  # Create the given file and check in an initial version of it

  Deleting
  --------
  TBD

  Moving
  ------
  TBD

  Branching
  ---------
  TBD

  Management
  ----------
  origen rc unman         # Show unmanaged files
  origen rc mods          # Show modified files in local workspace
  origen rc mods -a       # Show modified files in local workspace AND repository modifications
  origen rc tag           # Tag and release the application

The following commands are available:
  co              Checkout the whole application(default) or specific application files

  ci              Checkin the whole application(default) or specific application files

  tag             Tags the application, maintains the application history and emails the application users.
                  All files must be checked in before this command will be allowed to run.

                  The release note can be entered live during the release process or it can be prepared
                  beforehand. To prepare the note prior to release it should be  created in a file named
                  release_note.txt at the top level of your application.

                  Alternatively a different file can be used and specified via the -f option.

  mods            List any modified files in your workspace, or show the diffs vs. a previous tag.
                  Use the -v switch to supply a version to compare against.
                  Use the -a switch to include list of files updated in repository (Adds some time!)

  unman           List any unmanaged files in your workspace.

  init            Initialize a new application workspace (perform the first commit).

  new FILE [ORIG] Create and add a new file to revision control, then open the new file in the editor if you
                  have the $EDITOR environment variable defined.
                  Optionally supply a file from which the original version of the new file should be copied
                  from.

The following options are available:
  EOT
    opts.on('-h', '--help', 'Show this message') { puts opts; exit }
    app_options.each do |app_option|
      opts.on(*app_option) {}
    end
    opts.separator ''
    opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
    opts.on('-m', '--mode MODE', Origen::Mode::MODES, 'Force the Origen operating mode:', '  ' + Origen::Mode::MODES.join(', ')) { |_m| }
    opts.separator ''
    opts.separator "The following options apply to the 'tag' command only:"
    opts.on('-s', '--silent', "Release silently, don't send email notifications") { options[:silent] = true }
    opts.on('-l', '--local', 'Inhibit deploy or any other post tag tasks (application must implement)') { options[:local] = true }
    types = Origen::Application::Release.valid_types
    opts.on('-t', '--type TYPE', types, 'Release type:', '  ' + types.join(', ')) { |t| options[:type] = t ? t.to_sym : :development }
    opts.on('-n', '--note TEXT', String, 'Supply the release note') { |t| options[:note] = t }
    opts.on('-f', '--file FILE', String, 'Supply the release note in a file') { |f| options[:note_file] = f }
    unless Origen.config.semantically_version
      msg = 'Supply an explicit version identifier (tag)'
      opts.on('-i', '--identifier TEXT', String, msg) { |t| options[:tag] = t }
    end
    opts.on('--no-fetch', "Don't fetch the latest application files, i.e. tag the workspace as is") { options[:no_fetch] = true }
    opts.separator ''
    opts.separator "The following options apply to the 'mods' and 'co' commands only:"
    opts.on('-v', '--version TAG', String, 'Supply a version tag to compare against or checkout') { |f| options[:version] = f }
    opts.separator ''
    opts.separator "The following options apply to the 'mods' command only:"
    opts.on('-a', '--all', 'Include server modifications to files by others.') { options[:allmods] = true }
    opts.separator ''
    opts.separator "The following options apply to the 'co' command only:"
    opts.on('-f', '--force', 'Force overwrite of local edits') { options[:force] = true }
    opts.separator ''
    opts.separator "The following options apply to the 'ci' command only:"
    opts.on('--unman', 'Include un-managed files in the check in') { options[:unmanaged] = true }
  end

  opt_parser.parse! ARGV

  # Take the chance to clear world writable permissions to stop the annoying Ruby warnings
  dirs = Origen.root.to_s
  if File.exist?("#{dirs}/lbin")
    dirs += " #{dirs}/lbin"
  end
  `chmod o-w #{dirs}`

  if ARGV[0]
    case ARGV.shift
    when 'new'
      if ARGV[0]
        file = ARGV[0]
      else
        puts 'You must supply a path to the new file you want to create!'
        exit 1
      end
      if ARGV[1]
        `cp #{ARGV[1]} #{file}`
      else
        unless File.exist?(file)
          `touch #{file}`
        end
      end
      options[:comment] ||= 'Initial version'
      options[:unmanaged] = true
      Origen.app.rc.checkin(file, options)
      if ENV['EDITOR']
        spawn "#{ENV['EDITOR']} #{file} &"
      else
        puts "Created and checked in: #{file}"
      end

    when 'tag'
      Origen.app.release(options)

    when 'co'
      if ARGV.empty?
        path = workspace_dirs
      else
        path = ARGV.join(' ')
      end
      Origen.app.rc.checkout(path, version: options[:version], force: options[:force])

    when 'ci'
      if Origen.config.lint_test[:run_on_tag]
        Dir.chdir Origen.root do
          lint_dirs = []
          lint_files = []
          [Origen.config.lint_test[:files] || 'lib'].flatten.each do |f|
            if File.directory?(f)
              lint_dirs << f
            else
              lint_files << f
            end
          end

          if ARGV.empty?
            mods = Origen.app.rc.local_modifications
            if mods.empty?
              puts 'No changes to check in'
              exit 0
            else
              files = mods
            end
          else
            files = ARGV
          end

          lint = []
          files.each do |file|
            file = Pathname.new(file)
            if file.absolute?
              file = file.relative_path_from(Pathname.pwd).to_s
            else
              file = file.to_s
            end

            # Lint test any files or dirs that have specifically been marked for lint
            if lint_files.include?(file) || lint_dirs.include?(file)
              lint << file
            # Or any Ruby files within a marked directory
            elsif file =~ /.rb$/
              if lint_dirs.any? { |dir| file =~ /^#{dir}/ }
                lint << file
              end
            end
          end
          if lint.empty?
            result = true
          else
            result = system("origen lint #{lint.join(' ')}")
          end
          unless result
            puts ''
            puts 'Some lint/style errors were found, if these were all corrected just re-run the previous command, otherwise go and fix those that remain and then try again.'
            exit 1
          end
        end
      end

      # Don't allow force check-in via this API, if you want to do this you should really know what
      # you are doing and use the RC tool directly
      options.delete(:force)

      unless options[:comment]
        puts 'CHECKIN COMMENT:'
        options[:comment] = get_text.strip.gsub("\n", ' ')
      end
      if ARGV.empty?
        if options[:unmanaged]
          puts "--unman is not allowed at application level, use 'origen rc init' if you want"
          puts '        to commit a whole application for the first time.'
          exit 1
        else
          path = workspace_dirs
        end
      else
        path = ARGV.join(' ')
      end
      Origen.app.rc.checkin(path, options)

    when 'modifications', 'mods'
      if options[:allmods]
        options[:version] = nil
        puts 'Checking for differences vs. latest version ...'
      else
        if options[:version]
          puts "Checking for differences vs. #{options[:version]} ..."
        else
          puts 'Checking for local modifications ...'
        end
      end
      changes = []
      path_array = workspace_dirs.split(' ')
      puts
      if options[:version]
        all_changes = {
          added: [], removed: [], changed: []
        }
        # Check for changes in Origen.root and external app dirs
        path_array.each do |d|
          changes = Origen.app.rc.changes(d, options)
          if changes[:present]
            all_changes.merge!(changes) do |_key, old, new|
              if old.is_a? Array
                old << new
              else
                old || new
              end
            end
          end
        end
        if all_changes[:present]
          unless all_changes[:removed].empty?
            puts 'The following files have been removed:'
            all_changes[:removed].flatten.each do |file|
              puts "  #{file}"
            end
            puts ''
          end
          unless all_changes[:added].empty?
            puts 'The following files have been added:'
            all_changes[:added].flatten.each do |file|
              puts "  #{ENV['EDITOR']} #{file}"
            end
            puts ''
          end
          # Remove Origen controlled files that always change
          all_changes[:changed].reject! do |file|
            file == 'doc/history' || file == 'lib/origen/version.rb' || file == 'config/version.rb'
          end
          unless all_changes[:changed].empty?
            puts 'The following files are different:'
            all_changes[:changed].flatten.each do |file|
              puts "  #{Origen.app.rc.diff_cmd(file, options[:version])}"
            end
            puts ''
          end
        else
          puts 'Your workspace is clean!'
        end
      else
        path_array.each { |d| changes << Origen.app.rc.local_modifications(d, options) }
        changes.flatten!
        if changes.empty?
          puts 'Your workspace is clean!'
        else
          puts 'The following files have been modified:'
          changes.flatten.each do |file|
            if Origen.app.rc.git?
              puts "  #{Origen.app.rc.diff_cmd(file)}"
            else
              puts "  #{Origen.app.rc.diff_cmd(file, Origen.app.version)}"
            end
          end
        end
      end

    when 'unmanaged', 'unman'
      # merge standard with custom unmanaged dir/file lists
      unmanaged_dirs = _unmanaged_dirs
      unmanaged_files = _unmanaged_files
      # This method still very slow-- to improve need to skip listing
      # unmanaged directories in the first place, as they could hold many files
      filelist = Origen.app.rc.unmanaged.reject do |file|
        reject = false
        unmanaged_dirs.each do |dir_filter|
          if file =~ /^#{Regexp.escape(dir_filter)}\//i         # dir matching
            reject = true
          end
        end
        unless reject
          unmanaged_files.each do |file_filter|
            if file_filter =~ /\*/                      # wildcard used
              temp_file_filter = file_filter.gsub('.', '___')         # replace . with ___
              temp_file_filter2 = temp_file_filter.sub(/\*/, '')      # remove *
              temp_file = file.gsub('.', '___')                       # replace . with __
              if temp_file =~ /#{temp_file_filter2}/i
                reject = true
              end
            else
              if file.downcase == file_filter.downcase    # exact match
                reject = true
              end
            end
          end
        end
        reject
      end
      if filelist.size == 0
        puts 'Your workspace is clean!'
      else
        puts 'Your workspace has the following unmanaged files, run the given command to check them in:'
        filelist.each do |file|
          puts '  origen rc ci --unman ' + file
        end
      end

    when 'init', 'initialize'
      if !File.zero?("#{Origen.root}/doc/history") && !options[:force]
        puts "Sorry can't initialize, it looks like your app has already completed its first commit!"
      # TODO: Need the configuration to be made generic enough to handle Git and co.
      elsif !(Origen.app.config.rc_url || Origen.app.config.vault)
        puts 'Before initializing you must first set the rc_url/vault in config/application.rb'
      else
        puts ''
        puts 'You are about to commit this directory:'
        puts "  #{Origen.root}"
        puts ''
        puts 'To this url:'
        puts "  #{Origen.app.config.rc_url || Origen.app.config.vault}"
        puts ''
        puts 'DOES THAT LOOK CORRECT?   (if not update config.application.rb)'
        puts ''
        get_text confirm: true
        Origen::Log.console_only do
          Dir.chdir Origen.root do
            # Blow away these temporary files to make sure they are not committed
            Origen.import_manager.send(:remove_all_symlinks!) # removes symlinks from plugins
            system("rm -fr #{_unmanaged_dirs.join(' ')} #{_unmanaged_files.join(' ')}")
            options.delete(:force)
            options[:comment] ||= 'Initial'
            options[:unmanaged] = true
            options[:initial] = true
            if Origen.app.rc.git?
              Origen.app.rc.send(:create_gitignore) unless File.exist?("#{Origen.root}/.gitignore")
            end
            Origen.app.rc.checkin(options)
          end
        end
        puts
        puts "Your application is initialized, you can now use 'origen rc tag' to record its history"
      end

    else
      puts "Unknown command, see 'origen rc -h' for a list of commands"
    end
  else
    puts "You must supply a command, see 'origen rc -h' for a list of commands"
  end

  exit 0
end
