class RGenCoreApplication < RGen::Application

  self.name      = "RGen Core"
  self.namespace = "RGen"

  config.name = "RGen Core"
  config.initials = "RGen"
  config.vault = "sync://sync-15088:15088/Projects/common_tester_blocks/rgen"
  #config.rc_url = "ssh://git@sw-stash.freescale.net/rgen/rgen_core.git"
  config.semantically_version = true

  config.production_targets = {
    "1m79x" => "production",
    "2m79x" => "debug",
    "3m79x" => "mock.rb",
  }

  config.snapshots_directory do
    RGen.top.dirname
  end

  config.lint_test = {
    # Require the lint tests to pass before allowing a release to proceed
    :run_on_tag => true,
    # Auto correct violations where possible whenever 'rgen lint' is run
    :auto_correct => true, 
    # Limit the testing for large legacy applications
    #:level => :easy,
    # Run on these directories/files by default
    #:files => ["lib", "config/application.rb"],
  }

  #config.lsf.project = "rgen core"
  
  config.web_directory = "/proj/.web_rgen/html/rgen"

  config.web_domain = "http://rgen.freescale.net/rgen"
  
  config.pattern_prefix = "nvm"

  config.pattern_header do
    cc "This is a dummy pattern created by the RGen test environment"
  end

  # Add any directories or files not intended to be under change management control
  # standard RGen files/dirs already included
  # config.unmanaged_dirs = %w{dir1 dir2}
  # config.unamanged_files = %w{file1 file2 *.swp}

  config.output_directory do
    dir = "#{RGen.root}/output/#{$top.class}"
    dir.gsub!("::","_") if RGen.running_on_windows?
    dir
  end

  config.reference_directory do
    dir = "#{RGen.root}/.ref/#{$top.class}"
    dir.gsub!("::","_") if RGen.running_on_windows?
    dir
  end

  # Help RGen to find patterns based on an iterator
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

  # Ensure that all tests pass before allowing a release to continue
  def validate_release
    if !system("rgen specs") || !system("rgen examples")
      puts "Sorry but you can't release with failing tests, please fix them and try again."
      exit 1
    else
      puts "All tests passing, proceeding with release process!"
    end
  end

  def before_deploy_site
    Dir.chdir RGen.root do
      system "rgen specs -c"
      system "rgen examples -c"
      dir = "#{RGen.root}/web/output/coverage"       
      FileUtils.remove_dir(dir, true) if File.exists?(dir) 
      system "mv #{RGen.root}/coverage #{dir}"
    end
  end

  def after_release_email(tag, note, type, selector, options)
    begin
      pdm_release(:note => note)
    rescue
      RGen.log.error "PDM component release failed"
    end
    begin
      deployer = RGen.app.deployer
      if deployer.running_on_cde? && deployer.user_belongs_to_rgen?
        command = "rgen web compile --remote --api"
        # If an external release
        if RGen.version.production?
          command += " --archive #{RGen.app.version.prefixed}"
        end
        Dir.chdir RGen.root do
          system command
        end
      end
    rescue
      RGen.log.error "Web deploy failed"
    end
  end

  def pdm_release(options={})
    options = {
      :note_file => "release_note.txt",
    }.merge(options)
    if options[:note]
      note = options[:note]
    else
      note = File.open(options[:note_file]) { |f| f.read }
    end
    if RGen.version.production?
      RGen.app.pdm_component.pdm_version_notes = note
      RGen.app.pdm_component.pdm_release! 
    end
  end
end
