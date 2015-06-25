module Origen
  class Application
    # This class manages deploying an application's website.
    #
    # The web pages are compiled in the local application workspace and
    # deploy consists of copying them to the remote location.
    #
    # Two directories are maintained in the remote location, one containing the live
    # website and another where the new site is copied to during a deploy.
    # A symlink is used to indicate which one of the two directories is currently being
    # served.
    #
    # Upon a successful copy the symlink is switched over, thereby providing zero-downtime
    # deploys and guaranteeing that the old site will stay up if an error is encountered
    # during a deploy.
    class Deployer
      require 'fileutils'

      attr_writer :directory, :test

      def test_run?
        @test
      end

      def require_remote_directories
        %w(remote1 remote2).each do |dir|
          dir = "#{Origen.config.web_directory}/#{dir}"
          unless File.exist?(dir)
            FileUtils.mkdir_p dir
          end
        end
      end

      def latest_symlink
        "#{Origen.config.web_directory}/latest"
      end

      def offline_remote_directory
        if File.exist?(latest_symlink)
          if File.readlink(latest_symlink) =~ /remote1/
            "#{Origen.config.web_directory}/remote2"
          else
            "#{Origen.config.web_directory}/remote1"
          end
        else
          "#{Origen.config.web_directory}/remote1"
        end
      end

      def live_remote_directory
        if File.exist?(latest_symlink)
          if File.readlink(latest_symlink) =~ /remote1/
            "#{Origen.config.web_directory}/remote1"
          elsif File.readlink(latest_symlink) =~ /remote2/
            "#{Origen.config.web_directory}/remote2"
          end
        end
      end

      # Deploy a whole web site.
      #
      # This copies the entire contents of web/output in the application
      # directory to the remote server.
      def deploy_site
        Origen.app.listeners_for(:before_deploy_site).each(&:before_deploy_site)
        # Empty the contents of the remote dir
        if File.exist?(offline_remote_directory)
          FileUtils.remove_dir(offline_remote_directory, true)
          require_remote_directories
        end
        # Copy the new contents accross
        `chmod g+w -R #{Origen.root}/web/output`      # Ensure group writable
        FileUtils.cp_r "#{Origen.root}/web/output/.", offline_remote_directory
        `chmod g+w -R #{offline_remote_directory}`  # Double ensure group writable
        # Make live
        create_symlink offline_remote_directory, latest_symlink
        index = "#{Origen.config.web_directory}/index.html"
        # This symlink allows the site homepage to be accessed from the web root
        # directory rather than root directory/latest
        unless File.exist?(index)
          create_symlink "#{latest_symlink}/index.html", index
        end
      end

      def deploy_file(file)
        remote_dir = live_remote_directory
        if remote_dir
          file = Origen.file_handler.clean_path_to(file)
          sub_dir = Origen.file_handler.sub_dir_of(file, "#{Origen.root}/templates/web") .to_s
          page = file.basename.to_s.sub(/\..*/, '')
          # Special case for the main index page
          if page == 'index' && sub_dir == '.'
            FileUtils.cp "#{Origen.root}/web/output/index.html", remote_dir
          else
            FileUtils.mkdir_p("#{remote_dir}/#{sub_dir}/#{page}")
            FileUtils.cp "#{Origen.root}/web/output/#{sub_dir}/#{page}/index.html", "#{remote_dir}/#{sub_dir}/#{page}"
          end
        end
      end

      def generate_api
        dir = "#{Origen.root}/web/output/api"
        FileUtils.rm_rf(dir) if File.exist?(dir)
        # system("cd #{Origen.root} && rdoc --op api --tab-width 4 --main api_doc/README.txt --title 'Origen (#{Origen.version})' api_doc lib/origen")
        if Origen.root == Origen.top
          title = "#{Origen.config.name} #{Origen.version}"
        else
          title = "#{Origen.config.name} #{Origen.app.version}"
        end
        system("yard doc --output-dir #{Origen.root}/web/output/api --title '#{title}'")
      end

      def deploy_archive(id)
        dir = live_remote_directory
        if dir
          id.gsub!('.', '_')
          archive_dir = "#{Origen.config.web_directory}/#{id}"
          FileUtils.rm_rf(archive_dir) if File.exist?(archive_dir)
          FileUtils.mkdir_p archive_dir
          FileUtils.cp_r "#{Origen.root}/web/output/.", archive_dir
        end
      end

      def create_symlink(from, to)
        `rm -f #{to}` if File.exist?(to)
        `ln -s #{from} #{to}` if File.exist?(from)
      end

      def web_server_dir
        "#{Origen.root}/web"
      end

      def create_web_server_dir
        if File.exist?("#{Origen.root}/templates/web")
          dir = web_server_dir
          FileUtils.rm_rf dir if File.exist?(dir)
          FileUtils.mkdir_p dir
          # Copy the web infrastructure
          FileUtils.cp_r Dir.glob("#{Origen.top}/templates/nanoc/*").sort, dir
          # Compile the dynamic stuff
          Origen.app.runner.launch action: :compile,
                                   files:  "#{Origen.top}/templates/nanoc_dynamic",
                                   output: dir
          unless Origen.root == Origen.top
            # Copy any application overrides if they exist
            if File.exist?("#{Origen.root}/templates/nanoc")
              FileUtils.cp_r Dir.glob("#{Origen.root}/templates/nanoc/*").sort, dir, remove_destination: true
            end
          end
          # Remove the .SYNCs
          system "find #{dir} -name \".SYNC\" | xargs rm -fr"
          @nanoc_dir = dir
        end
      end
    end
  end
end
