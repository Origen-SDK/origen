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
  exit RSpec::Core::Runner.run(['spec/utility/collector_spec.rb', 'spec/utility_spec.rb'])

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
