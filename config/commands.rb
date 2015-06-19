# This file should be used to extend rgen with application specific tasks

aliases ={

}

@command = aliases[@command] || @command

case @command

when "specs"
  ARGV.unshift "spec"
  require "rspec"
  # For some unidentified reason Rspec does not autorun on this version
  if RSpec::Core::Version::STRING && RSpec::Core::Version::STRING == "2.11.1"
    RSpec::Core::Runner.run ARGV
  else
    require "rspec/autorun"
  end
  exit 0 # RSpec will exit 1 automatically if a test fails

when "examples"  
  $enable_testers = true if ARGV.delete("--testers")
  RGen.load_application
  status = 0
  Dir["#{RGen.root}/examples/*.rb"].each do |example|
    require example
  end
  
  if RGen.app.stats.changed_files == 0 &&
     RGen.app.stats.new_files == 0 &&
     RGen.app.stats.changed_patterns == 0 &&
     RGen.app.stats.new_patterns == 0

    RGen.app.stats.report_pass
  else
    RGen.app.stats.report_fail
    status = 1
  end
  puts
  exit status

when "regression"
  # You must tell the regression manager up front what target will be run within
  # the block
  options[:targets] = %w(debug v93k jlink bdm)
  RGen.regression_manager.run(options) do |options|
    RGen.lsf.submit_rgen_job "generate j750.list -t debug --plugin rgen_core_support"
    RGen.lsf.submit_rgen_job "generate v93k_workout -t v93k --plugin none"
    RGen.lsf.submit_rgen_job "generate dummy_name port -t debug --plugin none"
    RGen.lsf.submit_rgen_job "generate jlink.list -t jlink --plugin none"
    RGen.lsf.submit_rgen_job "generate bdm.list -t bdm --plugin none"
    RGen.lsf.submit_rgen_job "compile templates/test/set3 -t debug --plugin none"
    RGen.lsf.submit_rgen_job "compile templates/test/inspections.txt.erb -t debug --plugin none"
    RGen.lsf.submit_rgen_job "program program -t debug --plugin none"
    RGen.lsf.submit_rgen_job "program program -t debug --doc --plugin none"
  end
  exit 0

when "make_file"
  RGen.load_application
  system "touch #{RGen.root}/#{ARGV.first}"  
  exit 0

else
  @application_commands = <<-EOT
 specs        Run the specs (tests), -c will enable coverage
 examples     Run the examples, -c will enable coverage
 regression   Test the regression manager (runs a subset of examples)
  EOT

end 
