module RGen
  class Application
    # This class currently serves two APIs and is a bit of a mess.
    # The first API is the old style deploy which is deprecated, in this approach the
    # entire application was built and manged remotely with pages compiled in the remote
    # application.
    #
    # The new appraoch is that the web pages are compiled in the local application and
    # then deploy consists of simply copying them to the remote location.
    class Deployer
      require 'fileutils'

      attr_writer :version, :directory, :rgen_directory, :rdoc_command, :test

      # Deploys this release to rgen.freescale.net/tfs
      # This needs to be made generic so that projects can use it to, right now this
      # code exists both here and in the TFS project
      def deploy(options = {})
        options = {
          test:    false,         # Do a test run deploy in the local workspace
          archive: false
        }.merge(options)
        @directory = options[:directory]
        @app_sub_directory = options[:app_sub_directory]
        @test = options[:test]
        @version = options[:version]
        @rdoc_command = options[:rdoc_command]
        @successful = false

        puts '***********************************************************************'
        puts "'deploy' is deprecated, please transition to 'rgen web compile' instead"
        puts '***********************************************************************'

        begin
          puts ''
          puts 'Deploying...'
          puts ''
          populate(offline_release_dir) unless test_run?
          generate_web_pages
          generate_rdoc_pages if @rdoc_command
          # If web pages were generated compile them through nanoc, this is not done
          # as part of generate web pages to allow the application to add additional web
          # pages during the rdoc command
          if @nanoc_dir
            Dir.chdir @nanoc_dir do
              system 'nanoc'
            end
          end
          unless test_run?
            create_symlinks
            make_archive if options[:archive]
          end
          @successful = true
          true
        rescue Exception => e
          puts e.message
          puts e.backtrace
          deploy_unsuccessful(@directory)
          @successful = false
          false
        end
      end

      # Reports whether the last deploy was successful or not
      def successful?
        @successful
      end

      def test_run?
        @test
      end

      def require_remote_directories
        %w(remote1 remote2).each do |dir|
          dir = "#{RGen.config.web_directory}/#{dir}"
          unless File.exist?(dir)
            FileUtils.mkdir_p dir
          end
        end
      end

      def latest_symlink
        "#{RGen.config.web_directory}/latest"
      end

      def offline_remote_directory
        if File.exist?(latest_symlink)
          if File.readlink(latest_symlink) =~ /remote1/
            "#{RGen.config.web_directory}/remote2"
          else
            "#{RGen.config.web_directory}/remote1"
          end
        else
          "#{RGen.config.web_directory}/remote1"
        end
      end

      def live_remote_directory
        if File.exist?(latest_symlink)
          if File.readlink(latest_symlink) =~ /remote1/
            "#{RGen.config.web_directory}/remote1"
          elsif File.readlink(latest_symlink) =~ /remote2/
            "#{RGen.config.web_directory}/remote2"
          end
        end
      end

      # Deploy a whole web site.
      #
      # This copies the entire contents of web/output in the application
      # directory to the remote server.
      def deploy_site
        RGen.app.listeners_for(:before_deploy_site).each(&:before_deploy_site)
        # Empty the contents of the remote dir
        if File.exist?(offline_remote_directory)
          FileUtils.remove_dir(offline_remote_directory, true)
          require_remote_directories
        end
        # Copy the new contents accross
        `chmod g+w -R #{RGen.root}/web/output`      # Ensure group writable
        FileUtils.cp_r "#{RGen.root}/web/output/.", offline_remote_directory
        `chmod g+w -R #{offline_remote_directory}`  # Double ensure group writable
        # Make live
        create_symlink offline_remote_directory, latest_symlink
        index = "#{RGen.config.web_directory}/index.html"
        # This symlink allows the site homepage to be accessed from the web root
        # directory rather than root directory/latest
        unless File.exist?(index)
          create_symlink "#{latest_symlink}/index.html", index
        end
      end

      def deploy_file(file)
        remote_dir = live_remote_directory
        if remote_dir
          file = RGen.file_handler.clean_path_to(file)
          sub_dir = RGen.file_handler.sub_dir_of(file, "#{RGen.root}/templates/web") .to_s
          page = file.basename.to_s.sub(/\..*/, '')
          # Special case for the main index page
          if page == 'index' && sub_dir == '.'
            FileUtils.cp "#{RGen.root}/web/output/index.html", remote_dir
          else
            FileUtils.mkdir_p("#{remote_dir}/#{sub_dir}/#{page}")
            FileUtils.cp "#{RGen.root}/web/output/#{sub_dir}/#{page}/index.html", "#{remote_dir}/#{sub_dir}/#{page}"
          end
        end
      end

      def generate_api
        dir = "#{RGen.root}/web/output/api"
        FileUtils.rm_rf(dir) if File.exist?(dir)
        # system("cd #{RGen.root} && rdoc --op api --tab-width 4 --main api_doc/README.txt --title 'RGen (#{RGen.version})' api_doc lib/rgen")
        if RGen.root == RGen.top
          title = "#{RGen.config.name} #{RGen.version}"
        else
          title = "#{RGen.config.name} #{RGen.app.version}"
        end
        system("yard doc --output-dir #{RGen.root}/web/output/api --title '#{title}'")
      end

      def deploy_archive(id)
        dir = live_remote_directory
        if dir
          id.gsub!('.', '_')
          archive_dir = "#{RGen.config.web_directory}/#{id}"
          FileUtils.rm_rf(archive_dir) if File.exist?(archive_dir)
          FileUtils.mkdir_p archive_dir
          FileUtils.cp_r "#{RGen.root}/web/output/.", archive_dir
        end
      end

      # Make an archive directory for the current release, this will create
      # a new directory specifically for this release and copy over the web
      # pages and api docs.
      def make_archive
        if version == 'latest'
          puts 'Cannot archive latest, need a tag reference'
        else
          dir = archive_directory(force_clear: true)
          FileUtils.cp_r Dir.glob("#{rgen_directory}/web/output/*").sort, dir
          api = "#{archive_directory}/api"
          FileUtils.mkdir_p api unless File.exist?(api)
          FileUtils.cp_r Dir.glob("#{rgen_directory}/api/*").sort, api
        end
      end

      def create_symlinks
        {
          "#{rgen_directory}/web/output" => "#{root_directory}/latest",
          "#{rgen_directory}/api"        => "#{rgen_directory}/web/output/api"

        }.each do |from, to|
          create_symlink(from, to)
        end
      end

      def create_symlink(from, to)
        `rm -f #{to}` if File.exist?(to)
        `ln -s #{from} #{to}` if File.exist?(from)
      end

      def populate(dir)
        # Populate to the new tag
        system "dssc setvault #{RGen.config.vault} #{dir}"
        system "dssc pop -rec -uni -force -ver #{version} #{dir}"
      end

      def web_server_dir
        "#{rgen_directory}/web"
      end

      def create_web_server_dir
        if File.exist?("#{rgen_directory}/templates/web")
          dir = web_server_dir
          FileUtils.rm_rf dir if File.exist?(dir)
          FileUtils.mkdir_p dir
          # Copy the web infrastructure
          FileUtils.cp_r Dir.glob("#{RGen.top}/templates/nanoc/*").sort, dir
          # Compile the dynamic stuff
          RGen.app.runner.launch action: :compile,
                                 files:  "#{RGen.top}/templates/nanoc_dynamic",
                                 output: dir
          unless RGen.root == rgen_directory
            # Copy any application overrides if they exist
            if File.exist?("#{rgen_directory}/templates/nanoc")
              FileUtils.cp_r Dir.glob("#{rgen_directory}/templates/nanoc/*").sort, dir, remove_destination: true
            end
          end
          # Remove the .SYNCs
          system "find #{dir} -name \".SYNC\" | xargs rm -fr"
          @nanoc_dir = dir
        end
      end

      # Compiles and creates the web documentation pages, combining the RGen Jekyll
      # infrastructure and the application specific content
      def generate_web_pages
        if File.exist?("#{rgen_directory}/templates/web")
          create_web_server_dir
          # Finally compile the application web pages
          RGen.app.runner.generate(files:   "#{rgen_directory}/templates/web",
                                   compile: true,
                                   output:  "#{@nanoc_dir}/content")
        end
      end

      # Run the rdoc task
      def generate_rdoc_pages
        if File.exist?("#{rgen_directory}/templates/api_doc")
          RGen.app.runner.generate(files:   "#{rgen_directory}/templates/api_doc",
                                   compile: true,
                                   output:  "#{rgen_directory}/api_doc")
        end
        Dir.chdir rgen_directory do
          system "rgen #{rdoc_command}"
        end
      end

      def rdoc_command
        @rdoc_command || 'rdoc'
      end

      # The top level directory that hosts all releases
      def root_directory
        return @root_directory if @root_directory
        FileUtils.mkdir_p @directory unless File.exist?(@directory)
        @root_directory = @directory
      end

      # The directory that contains the current release
      def release_directory1
        return @release_directory1 if @release_directory1
        if test_run?
          @release_directory1 = RGen.root
        else
          @release_directory1 = "#{root_directory}/release_1"
          unless File.exist?(@release_directory1)
            FileUtils.mkdir_p @release_directory1
            populate(@release_directory1)
          end
        end
        @release_directory1
      end

      def release_directory2
        return @release_directory2 if @release_directory2
        if test_run?
          @release_directory2 = RGen.root
        else
          @release_directory2 = "#{root_directory}/release_2"
          unless File.exist?(@release_directory2)
            FileUtils.mkdir_p @release_directory2
            populate(@release_directory2)
          end
        end
        @release_directory2
      end

      def archive_directory(options = {})
        ver = version
        return RGen.root if test_run?
        if options[:force_clear]
          @archive_directory = "#{root_directory}/#{ver}"
          FileUtils.rm_rf @archive_directory if File.exist?(@archive_directory)
        else
          return @archive_directory if @archive_directory
          @archive_directory = "#{root_directory}/#{ver}"
        end
        FileUtils.mkdir_p @archive_directory unless File.exist?(@archive_directory)
        @archive_directory
      end

      def offline_release_dir
        link = "#{root_directory}/latest"
        if File.exist?(link)
          if File.readlink(link) =~ /release_1/
            @offline_release_dir = release_directory2
          else
            @offline_release_dir = release_directory1
          end
        else
          @offline_release_dir = release_directory1
        end
      end

      # The directory that contains the RGen app for the current release
      def rgen_directory
        return @rgen_directory if @rgen_directory
        if test_run?
          @rgen_directory = RGen.root
        else
          @rgen_directory = @app_sub_directory ? "#{offline_release_dir}/#{@app_sub_directory}" : offline_release_dir
          FileUtils.mkdir_p @rgen_directory unless File.exist?(@rgen_directory)
        end
        @rgen_directory
      end

      def version
        @version
      end

      # Returns true if the user account belongs to the rgen group
      def user_belongs_to_rgen?
        if RGen.running_on_windows?
          false
        else
          `"groups"`.gsub("\n", '').split(' ').include?('rgen')
        end
      end

      # Returns true if running on CDE
      def running_on_cde?
        if RGen.running_on_windows?
          false
        else
          !!(`"domainname"` =~ /cde/i)
        end
      end

      def deploy_unsuccessful(directory)
        puts ''
        puts "*** ERROR *** - Could not deploy to: #{directory}"
        puts ''
      end
    end
  end
end
