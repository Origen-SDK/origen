class OrigenCoreApplication < Origen::Application
  self.name      = "Origen Core"
  self.namespace = "Origen"

  config.name = "Origen Core"
  config.initials = "Origen"
  config.rc_url = "git@github.com:Origen-SDK/origen.git"
  config.semantically_version = true
  config.release_externally = true
  config.gem_name = "origen"

  config.production_targets = {
    "1m79x" => "production",
    "2m79x" => "debug",
    "3m79x" => "mock.rb",
  }

  config.lint_test = {
    # Require the lint tests to pass before allowing a release to proceed
    :run_on_tag => true,
    # Auto correct violations where possible whenever 'origen lint' is run
    :auto_correct => true, 
    # Limit the testing for large legacy applications
    #:level => :easy,
    # Run on these directories/files by default
    #:files => ["lib", "config/application.rb"],
  }

  config.remotes = [
    # To include the OrigenAppGenerators documentation in the main guides
    {
      dir: "origen_app_generators",
      rc_url: "https://github.com/Origen-SDK/origen_app_generators.git",
      version: "v1.1.0",
      development: true
    }
  ]

  #config.lsf.project = "origen core"
  
  #config.web_directory = "git@github.com:Origen-SDK/Origen-SDK.github.io.git/origen"
  config.web_directory = "https://github.com/Origen-SDK/Origen-SDK.github.io.git/origen"
  config.web_domain = "http://origen-sdk.org/origen"
  
  config.pattern_prefix = "nvm"

  config.application_pattern_header do |options|
    "This is a dummy pattern created by the Origen test environment"
  end

  # Add any directories or files not intended to be under change management control
  # standard Origen files/dirs already included
  # config.unmanaged_dirs = %w{dir1 dir2}
  # config.unamanged_files = %w{file1 file2 *.swp}

  config.output_directory do
    dir = "#{Origen.root}/output/#{$top.class}"
    dir.gsub!("::","_") if Origen.running_on_windows?
    dir
  end

  config.reference_directory do
    dir = "#{Origen.root}/.ref/#{$top.class}"
    dir.gsub!("::","_") if Origen.running_on_windows?
    dir
  end

  # Help Origen to find patterns based on an iterator
  config.pattern_name_translator do |name|
    if name == "dummy_name"
      {:source => "timing", :output => "timing"}
    else
      name.gsub(/_b\d/, "_bx")
    end
  end

  # By block iterator
  config.pattern_iterator do |iterator|
    iterator.key = :by_block

    iterator.loop do |&pattern|
      $nvm.blocks.each do |block|
        pattern.call(block)
      end
    end

    iterator.setup do |block|
      blk = $nvm.find_block_by_id(block.id)
      blk.select
      blk
    end

    iterator.pattern_name do |name, block|
      name.gsub("_bx", "_b#{block.id}")
    end
  end

  # By setting iterator
  config.pattern_iterator do |iterator|
    iterator.key = :by_setting

    iterator.loop do |settings, &pattern|
      settings.each do |setting|
        pattern.call(setting)
      end
    end

    iterator.pattern_name do |name, setting|
      name.gsub("_x", "_#{setting}")
    end
  end

  def after_web_compile(options)
    Origen.app.plugins.each do |plugin|
      if plugin.config.shared && plugin.config.shared[:origen_guides]
        Origen.app.runner.launch action: :compile,
                                 files:  File.join(plugin.root, plugin.config.shared[:origen_guides]),
                                 output: File.join('web', 'content', 'guides')
      end
    end
  end

  # Ensure that all tests pass before allowing a release to continue
  def validate_release
    if !system("origen specs") || !system("origen examples")
      puts "Sorry but you can't release with failing tests, please fix them and try again."
      exit 1
    else
      puts "All tests passing, proceeding with release process!"
    end
  end

  #def before_deploy_site
  #  Dir.chdir Origen.root do
  #    system "origen specs -c"
  #    system "origen examples -c"
  #    dir = "#{Origen.root}/web/output/coverage"       
  #    FileUtils.remove_dir(dir, true) if File.exists?(dir) 
  #    system "mv #{Origen.root}/coverage #{dir}"
  #  end
  #end

  def after_release_email(tag, note, type, selector, options)
    begin
      command = "origen web compile --remote --api --comment 'Release of #{Origen.app.name} #{Origen.app.version}'"
      Dir.chdir Origen.root do
        system command
      end
    rescue
      Origen.log.error "Web deploy failed"
    end
  end
end
