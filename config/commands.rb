# This file should be used to extend origen with application specific tasks

aliases ={

}

@command = aliases[@command] || @command

case @command

when "tags"
  Dir.chdir Origen.root do
    system "ripper-tags --recursive lib"
  end
  exit 0

when "specs"
  require "rspec"

  options = {}
  opt_parser = OptionParser.new do |opts|
    opts.banner = [
      'Run the specs unit tests',
      'Usage: origen specs [filename_substrings...] [options]',
      "Note: all files must reside in #{Origen.app.root}/specs for filename substrings",
      "E.g.: origen specs site_config #=> runs only specs in filenames matching 'site_config'"
    ].join("\n")
    opts.on('-h', '--help', 'Show this help message') do |h|
      puts opt_parser
      exit!
    end
  end
  opt_parser.parse! ARGV

  # Search for the filenames given. 
  spec_files = ARGV.map do |file|
    f = Pathname.new(file)
    dir = Origen.app.root.join('spec')

    # Find any files that match the name. Include all these files.
    # Note that this will map a string to an array, so we'll flatten the array later.
    # Also, we'll only search for .rb files in spec. Append that to the glob if no file ext is provided.
    if f.exist? && f.extname == '.rb'
      # This is a hard-coded path. Don't glob this, just make sure its witin the spec directory.
      File.expand_path(f)
    elsif f.extname == '.rb'
      # Search includes the extension, so don't add it.
      # (limited to .rb files)
      Dir.glob(dir.join("**/*#{f}"))
    else
      # Search for matching ruby files.
      # (limited to .rb files)
      Dir.glob(dir.join("**/*#{f}*.rb"))
    end
  end
  spec_files.flatten!

  if ARGV.empty?
    # No filename substrings given. Run all *_spec files in spec/ directory
    spec_files = ['spec']
  elsif spec_files.empty? && !ARGV.empty?
    # The spec files to run is empty, but file substring were given.
    # Report that no files were found and exit.
    Origen.app!.fail!(message: "No matching spec files could be found at #{Origen.app.root}/spec for patterns: #{ARGV.join(', ')}")
  else
    # Filename substrings were given and matching files were found. List the files just for user awareness.
    Origen.log.info "Found matching specs files for patterns: #{ARGV.join(', ')}"
    spec_files.each { |f| Origen.log.info(f) }
  end

  current_mode = Origen.mode.instance_variable_get(:@current_mode)
  Origen.mode = :debug
  Origen.app.session.origen_core[:mode] = Origen.mode.to_s
  begin
    status = RSpec::Core::Runner.run(spec_files)
  rescue SystemExit => e
    Origen.log.error "Unexpected SystemExit reached. Reporting failure status..."
    status = 1
  end
  Origen.mode = current_mode
  Origen.app.session.origen_core[:mode] = Origen.mode.to_s
  
  # One kind of confusing thing is that Specs can still print the 'pass'/'success' verbiage even when it actually failed.
  # This is due to rspec itself catching the errors, so there's no exception to catch from outside Rspec.
  # Most likely the user will see red and see that nothing was actually run, but print a reassuring message from Origen saying that the specs actually failed,
  # despite what Rspec's verbiage says.
  if status == 1
    Origen.log.error "Some errors occurred outside of the examples: received exit status 1 (failure). Please review RSpec output for details."
  end

  exit(status)

when "examples", "test"  
  Origen.load_application
  status = 0
  Dir["#{Origen.root}/examples/*.rb"].each do |example|
    require example
  end
  
  if Origen.app.stats.changed_files == 0 &&
     Origen.app.stats.new_files == 0 &&
     Origen.app.stats.changed_patterns == 0 &&
     Origen.app.stats.new_patterns == 0

    Origen.app.stats.report_pass
  else
    Origen.app.stats.report_fail
    status = 1
  end
  puts
  if @command == "test"
    Origen.app.unload_target!
    require "rspec"
    result = RSpec::Core::Runner.run(['spec'])
    status = status == 1 ? 1 : result
  end
  exit status

when "regression"
  # You must tell the regression manager up front what target will be run within
  # the block
  options[:targets] = %w(debug v93k jlink)
  Origen.regression_manager.run(options) do |options|
    Origen.lsf.submit_origen_job "generate j750.list -t debug --plugin origen_core_support"
    Origen.lsf.submit_origen_job "generate v93k_workout -t v93k --plugin none"
    Origen.lsf.submit_origen_job "generate dummy_name port -t debug --plugin none"
    Origen.lsf.submit_origen_job "generate jlink.list -t jlink --plugin none"
    Origen.lsf.submit_origen_job "compile templates/test/set3 -t debug --plugin none"
    Origen.lsf.submit_origen_job "compile templates/test/inspections.txt.erb -t debug --plugin none"
    Origen.lsf.submit_origen_job "program program -t debug --plugin none"
    Origen.lsf.submit_origen_job "program program -t debug --doc --plugin none"
  end
  exit 0

when "make_file"
  Origen.load_application
  system "touch #{Origen.root}/#{ARGV.first}"  
  exit 0

else
  @application_commands = <<-EOT
 specs        Run the specs (unit tests), -c will enable coverage
 examples     Run the examples (acceptance tests), -c will enable coverage
 test         Run both specs and examples, -c will enable coverage
 regression   Test the regression manager (runs a subset of examples)
 tags         Generate ctags for this app
  EOT

end 
