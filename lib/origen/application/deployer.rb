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
    #
    # An alternative method of deploying is also supported by pushing to a Git repository.
    class Deployer
      require 'fileutils'

      attr_writer :directory, :test

      # Prepare for deploying, this will raise an error if the current user is found to
      # have insufficient permissions to deploy to the target directory
      def prepare!(options = {})
        if deploy_to_git?
          require 'highline/import'
          @commit_message = options[:message] || options[:comment] || ask('Enter a deployment commit message:  ') do |q|
            q.validate = /\w/
            q.responses[:not_valid] = "Can't be blank"
          end
          Origen.log.info "Fetching the website's Git respository..."
          git_repo
          begin
            fail unless git_repo.can_checkin?
          rescue
            puts "Sorry, but you don't have permission to write to #{Origen.config.web_directory}!"
            exit 1
          end
        else
          begin
            require_remote_directories
            test_file = "#{Origen.config.web_directory}/_test_file.txt"
            FileUtils.rm_f(test_file) if File.exist?(test_file)
            FileUtils.touch(test_file)
            FileUtils.rm_f(test_file)
          rescue
            puts "Sorry, but you don't have permission to write to #{Origen.config.web_directory}!"
            exit 1
          end
        end
      end

      def git_sub_dir
        if Origen.config.web_directory =~ /\.git\/(.*)$/
          Regexp.last_match(1)
        end
      end

      # Returns a RevisionControl::Git object that points to a local copy of the website repo
      # which is will build and checkout as required
      def git_repo
        @git_repo ||= begin
          local_path = "#{Origen.config.web_directory.gsub('/', '-').symbolize}"
          local_path.gsub!(':', '-') if Origen.os.windows?
          local = Pathname.new("#{Origen.app.workspace_manager.imports_directory}/git/#{local_path}")
          if git_sub_dir
            remote = Origen.config.web_directory.sub("\/#{git_sub_dir}", '')
          else
            remote = Origen.config.web_directory
          end
          git = RevisionControl::Git.new(local: local, remote: remote)
          if git.initialized?
            git.checkout(force: true)
          else
            git.build(force: true)
          end
          git
        end
      end

      def test_run?
        @test
      end

      def deploy_to_git?
        !!(Origen.config.web_directory =~ /\.git\/?#{git_sub_dir}$/)
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
        if deploy_to_git?
          dir = git_repo.local.to_s
          dir += "/#{git_sub_dir}" if git_sub_dir
          # Delete everything so that we don't preserve old files
          git_repo.delete_all(git_sub_dir)
          FileUtils.mkdir_p(dir) unless File.exist?(dir)
          `chmod a+w -R #{Origen.root}/web/output`      # Ensure world writable, required?
          FileUtils.cp_r "#{Origen.root}/web/output/.", dir
          git_repo.checkin git_sub_dir, unmanaged: true, comment: @commit_message
        else
          # Empty the contents of the remote dir
          if File.exist?(offline_remote_directory)
            FileUtils.remove_dir(offline_remote_directory, true)
            require_remote_directories
          end
          # Copy the new contents across
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
      end

      def deploy_file(file)
        remote_dir = deploy_to_git? ? "#{git_repo.local}/#{git_sub_dir}" : live_remote_directory
        if remote_dir
          file = Origen.file_handler.clean_path_to(file)
          sub_dir = Origen.file_handler.sub_dir_of(file, "#{Origen.root}/templates/web") .to_s
          page = file.basename.to_s.sub(/\..*/, '')
          # Special case for the main index page
          if page == 'index' && sub_dir == '.'
            FileUtils.cp "#{Origen.root}/web/output/index.html", remote_dir
            file = "#{remote_dir}/index.html"
          else
            FileUtils.mkdir_p("#{remote_dir}/#{sub_dir}/#{page}")
            file = "#{remote_dir}/#{sub_dir}/#{page}/index.html"
            FileUtils.cp "#{Origen.root}/web/output/#{sub_dir}/#{page}/index.html", file
          end
          if deploy_to_git?
            git_repo.checkin file, unmanaged: true, comment: @commit_message
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
        # Yard doesn't have an option to ignore github-style READMEs, so force it here to
        # always present the API index on the API homepage for consistency
        index = "#{Origen.root}/web/output/api/index.html"
        _index = "#{Origen.root}/web/output/api/_index.html"
        FileUtils.rm_f(index) if File.exist?(index)
        # This removes a prominent link that we are left with to a README file that doesn't work
        require 'nokogiri'
        doc = Nokogiri::HTML(File.read(_index))
        doc.xpath('//h2[contains(text(), "File Listing")]').remove
        doc.css('#files').remove
        File.open(_index, 'w') { |f| f.write(doc.to_html) }
        FileUtils.cp(_index, index)
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
          @nanoc_dir = dir
        end
      end
    end
  end
end
