require 'colored'
module Origen
  class Application
    # Responsible for co-ordinating application releases
    class Release
      include Users
      include Utility::TimeAndDate
      include Utility::InputCapture
      include Utility

      def initialize
        @mailer = Utility::Mailer.new
      end

      def self.valid_types
        if Origen.config.semantically_version
          if Origen.app.version.development?
            [:development, :production]
          else
            [:development, :tiny, :minor, :major]
          end
        else
          [:development, :production]
        end
      end

      # Release a new application version
      def run(options)
        # Don't want plugin callbacks kicking in during the release process
        Origen.app.plugins.disable_current
        @options = options
        if authorized?
          Origen.app.plugins.validate_production_status(true)
          fail 'No revision control configured for this application, cannot release a new version' if Origen.app.rc.nil?
          unless Origen.app.rc.local_modifications.empty?
            puts <<-EOT
Your workspace has local modifications that are preventing the requested action
  - run 'origen rc mods' to see them.
            EOT
            exit 1
          end
          get_release_type unless type
          validate_branch
          # For development tags always include the latest updates from everyone else,
          # for production tag exactly what is in the user's workspace
          if type == :development && !options[:no_fetch]
            puts 'Fetching the latest version of all application files...'
            Origen.app.rc.checkout(force: true)
          end
          Origen.app.listeners_for(:validate_release).each(&:validate_release)
          lint_test
          get_latest_version_files
          base_version = Origen.app.version(refresh: true)  # Read in the latest version
          get_release_note unless note
          new_version = get_or_confirm_version(type)  # Don't mask this like the above!
          write_version(new_version)
          # Refresh the version in the current thread
          Origen.app.version(refresh: true)
          if Origen.app.version != new_version
            fail "Sorry something has gone wrong trying to update the version counter to #{new_version}!"
          end
          Origen.app.version_tracker.add_version(Origen.app.version) if Origen.app.version.production?
          write_history
          Origen.app.listeners_for(:before_release_tag).each do |listener|
            listener.before_release_tag(tag, note, type, selector, options)
          end
          puts "Tagging workspace, this could take a few minutes, don't interrupt..."
          Origen.app.rc.checkin("#{version_file} #{history_file} #{File.join(Origen.root, 'Gemfile.lock')}", force: true, comment: 'Updated app version and history')
          workspace_dirs.each do |wdir|
            Origen.app.rc.tag tag
          end
          begin
            Origen.client.release!
          rescue
            # Don't allow any server post errors to kill the release process
          end
          release_gem
          Origen.app.listeners_for(:after_release_tag).each do |listener|
            listener.after_release_tag(tag, note, type, selector, options)
          end
          @mailer.send_release_notice(tag, note, type, selector) unless options[:silent]
          Origen.app.listeners_for(:after_release_email).each do |listener|
            listener.after_release_email(tag, note, type, selector, options)
          end
          puts "Successfully released version #{Origen.app.version}!"
        end
      end

      protected

      def validate_branch
        if Origen.app.rc.git?
          if Origen.app.config.rc_workflow == :gitflow
            if type == :development && Origen.app.rc.current_branch == 'master'
              puts "Development releases can only be made on the develop branch, your current branch is: #{Origen.app.rc.current_branch}"
              exit 1
            elsif type == :production && Origen.app.rc.current_branch != 'master'
              puts "Production releases can only be made on the master branch, your current branch is: #{Origen.app.rc.current_branch}"
              exit 1
            end
          end
        end
      end

      def release_gem
        if File.exist?(File.join Origen.root, "#{Origen.app.gem_name}.gemspec")
          Origen.app.listeners_for(:before_release_gem).each(&:before_release_gem)
          unless system 'rake gem:release'
            puts '***************************************'.red
            puts '***************************************'.red
            puts 'SOMETHING WENT WRONG RELEASING THE GEM!'.red
            puts '***************************************'.red
            puts '***************************************'.red
          end
          Origen.app.listeners_for(:after_release_gem).each(&:after_release_gem)
        end
      end

      # Run the lint test and require that it passes if enabled
      def lint_test
        if Origen.config.lint_test[:run_on_tag]
          unless system('origen lint --no-correct')
            puts ''
            puts "Can't release due to lint/style errors, fix any errors from running 'origen lint' before trying again"
            exit 1
          end
        end
      end

      # Sets the current release type
      def type=(type)
        type = type.to_s.chomp.downcase.to_sym
        @type = self.class.valid_types.include?(type) ? type : nil
      end

      def type
        @type ||= @options[:type]
      end

      # Sets the release note, returns nil if invalid
      def note=(note)
        if note.to_s =~ /[a-f]|[A-F]/
          @note = note
        else
          @note = nil
        end
      end

      def note
        @note ||= @options[:note]
      end

      # Returns the selector, formatted as a string
      def selector
        "Branch: '#{Origen.app.rc.current_branch}'"
      end

      def version_file
        File.join(Origen.root, 'config', 'version.rb')
      end

      def history_file
        Origen.config.history_file
      end

      def workspace_dirs
        dirs = ["#{Origen.root}"]
        Origen.app.config.external_app_dirs.each do |edir|
          dirs << edir
        end
        dirs
      end

      # Pull the latest versions of the history and version ID files into the workspace
      def get_latest_version_files
        # Get the latest version of the version and history files
        if Origen.app.rc.dssc?
          # Legacy code that makes use of the fact that DesignSync can handle different branch selectors
          # for individual files, this capability has not been abstracted by the newer object oriented
          # revision controllers since most others cannot do it
          system "dssc co -get -force \"#{history_file};Trunk:Latest\" #{version_file}"
          # Force the history selector to Trunk, only 1 branch of this file should ever exist
          system "dssc setselector Trunk #{history_file}"
          # Make sure both are writable
          if Origen.running_on_windows?
            `attrib -R #{history_file.gsub('/', '\\')} #{version_file.gsub('/', '\\')}`
          else
            `chmod 666 #{history_file} #{version_file}`
          end
        else
          Origen.app.rc.checkout "#{history_file} #{version_file}", force: true
        end
      end

      # Prompts the user to enter a release note
      def get_release_note
        puts ''
        if @options[:note_file]
          f = Origen.file_handler.clean_path_to(@options[:note_file])
        else
          f = "#{Origen.root}/release_note.txt"
        end
        if File.exist?(f)
          lines = File.readlines(f)
          puts 'HAPPY TO USE THIS RELEASE NOTE?:'
          puts '------------------------------------------------------------------------------------------'
          lines.each { |l| puts l }
          puts '------------------------------------------------------------------------------------------'
          if get_text(confirm: :return_boolean)
            self.note = lines.join('')
            return if note
          end
        end
        puts 'RELEASE NOTE:'
        self.note = get_text
        unless note
          puts 'Sorry but you must supply at least a minor description for this release!'
          get_release_note
        end
      end

      # Prompts the user to enter a release type
      def get_release_type
        puts ''
        puts "RELEASE TYPE (#{self.class.valid_types.join(', ')}):"
        self.type = get_text(default: self.class.valid_types.first, single: true)
        unless type
          puts 'Sorry but that release type is not valid!'
          get_release_type
        end
      end

      # Prompts the user to confirm the proposed version or enter a different one
      def get_or_confirm_version(type)
        proposed = nil
        until version_unique?(proposed)
          proposed ||= Origen.app.version
          if type == :development
            proposed = proposed.next_dev
          else
            proposed = proposed.next_prod(type)
          end
        end
        if Origen.config.semantically_version
          puts
          puts 'HAPPY TO RELEASE THIS VERSION?:'
          unless get_text(default: proposed, confirm: :return_boolean)
            valid = false
            puts
            until valid
              puts
              puts 'ENTER THE VERSION NUMBER YOU WOULD LIKE TO USE INSTEAD:'
              proposed = Origen::VersionString.new(get_text(single: true).strip)
              valid = proposed.semantic?
              unless valid
                puts 'SORRY BUT THAT IS NOT A VALID VERSION NUMBER'
              end
            end
          end
        else
          valid = false
          until valid
            puts
            puts 'RELEASE TAG:'
            proposed = Origen::VersionString.new(get_text(default: proposed, single: true).strip)
            valid = proposed.timestamp?
            unless valid
              puts 'SORRY BUT THAT IS NOT A VALID VERSION NUMBER'
            end
          end
        end
        proposed
      end

      def version_unique?(version)
        if version
          if version.semantic?
            if Origen.app.rc.git?
              !Origen.app.rc.tag_exists?(version.prefixed)
            else
              # Don't worry about dssc, since a single branch is used for the version it will
              # always be unique
              true
            end
          else
            true
          end
        end
      end

      # For now apply a leading 'v' to keep design sync happy, will make this CM type
      # specific in future
      def tag
        tag = Origen.app.version
        if tag =~ /^\d/
          Origen.app.config.rc_tag_prepend_v ? "v#{tag}" : tag
        else
          tag
        end
      end

      # Write out details of the given version to the history file
      def write_history
        text = File.read(history_file)           # Read the existing contents
        File.open(history_file, 'w') do |file|   # Write them back, substituting the version number as required
          if Origen.app.version.production?
            file.puts "<a class=\"anchor release_tag\" name=\"#{tag.gsub('.', '_')}\"></a>"
            file.puts "<h1><a href=\"##{tag.gsub('.', '_')}\">Tag: #{tag}</a></h1>"
            file.puts ''
            file.puts "##### #{selector}".escape_underscores
            file.puts ''
            file.puts "##### by #{User.current.name} on #{time_now}"
            file.puts ''
          else
            file.puts "<a class=\"anchor release_tag\" name=\"#{tag.gsub('.', '_')}\"></a>"
            file.puts "<h2><a href=\"##{tag.gsub('.', '_')}\">Tag: #{tag}</a></h2>"
            file.puts ''
            file.puts "##### #{selector}".escape_underscores
            file.puts ''
            file.puts "##### by #{User.current.name} on #{time_now}"
            file.puts ''
          end
          file.puts ''
          file.puts note.escape_underscores(smartly)
          file.puts ''
          file.puts text
        end
      end

      # Sets the version number in the file store
      def write_version(version)
        if version.semantic?
          Origen::CodeGenerators.invoke_internal 'semver', [], config: { change: version }
        else
          Origen::CodeGenerators.invoke_internal 'timever', [], config: { change: version }
        end
        system 'origen -v' # Invoke Origen under the new version, this updates Gemfile.lock
      end

      # Only allows admins to release
      def authorized?
        # Not sure yet if this concept can work in the open source world...
        true
        # if User.current.admin?
        #  true
        # else
        #  puts "Sorry but you can't run the release script, please contact a development team member"
        #  false
        # end
      end
    end
  end
end
