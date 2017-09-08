require 'optparse'
require 'pathname'
require 'origen/commands/helpers'

module Origen
  extend CommandHelpers

  options = {}

  # App options are options that the application can supply to extend this command
  app_options = @application_options || []
  opt_parser = OptionParser.new do |opts|
    opts.banner = <<-END
Usage: origen web CMD [options]

The following commands are available:
  new             Create a fresh web directory (this will delete any existing compiled files!).
                  A new directory will automatically be created if you don't have one when you run the compile
                  command, however if for some reason you want to start fresh you can run this command to do so.

  serve           Start a webserver from the current directory

  compile [FILE]  Compile all web templates and start a server to view them, optionally supply a
                  file argument to only update a single page e.g. 'origen web compile templates/web/index.md.erb'
                  Use the --remote option to copy the compiled files to a remote web server directory (the
                  location of which should be specified via Origen.config.web_directory). In this case when no
                  FILE argument is specified the entire site will be copied over to a fresh web server
                  directory and the live site will be switched over when complete.
                  When a FILE argument is present the specified file(s) will be compiled directly to the live
                  production site.

  deploy [FILE]   Same as compile with --remote except that the actual compilation step will be skipped - i.e.
                  use this in cases where you already have long-running templates pre-compiled.
                  The api generation step will also be skipped if the --api option is supplied.

  archive ID      Archive the current contents of your live website under the given ID. This is normally used
                  to archive the documents for a specific production release, so "origen web archive Rel20120112"
                  would be viewable at <your_domain>/Rel20120112.

The following options are available:
    END
    opts.on('-e', '--environment NAME', String, 'Override the default environment, NAME can be a full path or a fragment of an environment file name') { |e| options[:environment] = e }
    opts.on('-t', '--target NAME', String, 'Override the default target, NAME can be a full path or a fragment of a target file name') { |t| options[:target] = t }
    opts.on('-r', '--remote', 'Use in conjunction with the compile command to deploy files to a remote web server') {  options[:remote] = true }
    opts.on('-a', '--api', 'Generate API documentation after compiling') {  options[:api] = true }
    opts.on('--archive ID', String, 'Archive the documents after compiling or deploying remotely') do |id|
      options[:archive] = id
      require "#{Origen.top}/helpers/url"
      Origen::Generator::Compiler::Helpers.archive_name = id
    end
    opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
    opts.on('-m', '--mode MODE', Origen::Mode::MODES, 'Force the Origen operating mode:', '  ' + Origen::Mode::MODES.join(', ')) { |_m| }
    opts.on('--no-serve', "Don't serve the website after compiling without the remote option") { options[:no_serve] = true }
    opts.on('-c', '--comment COMMENT', String, 'Supply a commit comment when deploying to Git') { |o| options[:comment] = o }
    # Apply any application option extensions to the OptionParser
    extend_options(opts, app_options, options)
    opts.separator ''
    opts.on('-h', '--help', 'Show this message') { puts opts; exit }
  end
  opt_parser.parse! ARGV

  Origen.load_application
  Origen.environment.temporary = options[:environment] if options[:environment]
  Origen.target.temporary = options[:target] if options[:target]

  def self._require_web_directory
    unless Origen.config.web_directory
      puts 'To run that command you must specify the location of your webserver, for example:'
      puts ''
      puts '# config/application.rb'
      puts 'config.web_directory = "/proj/.web_origen/html/origen"'
      exit 1
    end
  end

  def self._start_server
    # Get the current host
    host = `hostname`.strip.downcase
    if Origen.running_on_windows?
      domain = 'fsl.freescale.net'
    else
      domain = `dnsdomainname`.strip
    end
    # Get a free port
    require 'socket'
    port = 8000 # preferred port
    begin
      server = TCPServer.new('127.0.0.1', port)
    rescue Errno::EADDRINUSE
      # port = rand(65000 - 1024) + 1024
      port += 1
      retry
    end
    server.close
    # Start the server
    puts ''
    puts "Point your browser to this address:  http://#{host}#{domain.empty? ? '' : '.' + domain}:#{port}"
    puts ''
    puts 'To shut down the server use CTRL-C'
    puts ''
    system "ruby -run -e httpd . -p #{port}"
  end

  def self._build_web_dir
    _deployer.create_web_server_dir

    dir = Pathname.new(_deployer.web_server_dir).relative_path_from(Pathname.pwd)

    puts "Web server directory created at: #{dir}"
    puts ''
    puts "Compile any files you want to test into the #{dir}/content directory, e.g.:"
    puts "  origen c templates/file.md.erb -o #{dir}/content"
    puts ''
    puts 'To turn them into web pages:'
    puts "  cd #{dir}"
    if Origen.running_on_windows?
      puts '  nanoc'
    else
      puts '  env LANG=en_US.UTF-8 nanoc'
    end
    puts ''
    puts 'To start a web server for remote viewing:'
    puts "  cd #{dir}/output"
    puts '  origen web serve'
  end

  def self._deployer
    @_deployer ||= Origen.app.deployer
    @_deployer.test = true
    @_deployer
  end

  if ARGV[0]
    case ARGV.shift
    when 'serve'
      _start_server
    when 'new'
      _build_web_dir
    when 'compile'
      if options[:remote]
        Origen.app.load_target!
        _require_web_directory
        _deployer.prepare!(options)
        # If the whole site has been requested that start from a clean slate
        _build_web_dir if ARGV.empty?
      else
        Origen.app.load_target!(force_debug: true)
        Origen.set_development_mode
      end
      options[:files] = ARGV.dup
      if ARGV.empty?
        _build_web_dir
        Dir.chdir Origen.root do
          Origen.app.listeners_for(:before_web_compile).each do |listener|
            listener.before_web_compile(options)
          end
          Origen.app.runner.launch action: :compile,
                                   files:  'templates/web',
                                   output: 'web/content'
          Origen.app.listeners_for(:after_web_compile).each do |listener|
            listener.after_web_compile(options)
          end
          Origen.app.listeners_for(:after_web_site_compile).each do |listener|
            listener.after_web_site_compile(options)
          end
        end

      else
        _build_web_dir unless File.exist?("#{Origen.root}/web")
        Origen.app.listeners_for(:before_web_compile).each do |listener|
          listener.before_web_compile(options)
        end
        ARGV.each do |file|
          output = Origen.file_handler.sub_dir_of(Origen.file_handler.clean_path_to(file), "#{Origen.root}/templates/web")
          Origen.app.runner.launch action: :compile,
                                   files:  file,
                                   output: "#{Origen.root}/web/content/#{output}"
        end
        Origen.app.listeners_for(:after_web_compile).each do |listener|
          listener.after_web_compile(options)
        end
      end
      Dir.chdir "#{Origen.root}/web" do
        system "#{Origen.root}/lbin/nanoc"
      end
      if options[:api]
        _deployer.generate_api
      end
      if options[:remote]
        if ARGV.empty?
          _deployer.deploy_site
        else
          ARGV.each do |files|
            Origen.file_handler.resolve_files(files) do |file|
              _deployer.deploy_file(file)
            end
          end
        end
        _deployer.deploy_archive(options[:archive]) if options[:archive]
      else
        unless options[:no_serve]
          Dir.chdir "#{Origen.root}/web/output" do
            _start_server
          end
        end
      end

    when 'deploy'
      Origen.app.load_target!
      _require_web_directory
      _deployer.prepare!(options)
      if ARGV.empty?
        _deployer.deploy_site
      else
        ARGV.each do |files|
          Origen.file_handler.resolve_files(files) do |file|
            _deployer.deploy_file(file)
          end
        end
      end
      _deployer.deploy_archive(options[:archive]) if options[:archive]

    when 'archive'
      Origen.app.load_target!
      _require_web_directory
      _deployer.prepare!(options)
      unless ARGV[0]
        puts 'You must supply an ID argument to create an archive'
      end
      _deployer.deploy_archive(ARGV[0])

    else
      puts "Unknown command, see 'origen web -h' for a list of commands"
    end
  else
    puts "You must supply a command, see 'origen web -h' for a list of commands"
  end
end
