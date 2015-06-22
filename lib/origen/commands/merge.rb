require 'optparse'

options = {}
Origen.log.deprecate <<-END

********************************************************************************************
  The 'merge' command has now been deprecated as the same functionality can be achieved by
  performing the following tasks:

  origen compile [COMPILE DIRECTORY/FILE] -r [DIRECTORY/FILE FOR COMPARISON]

  By using the -r switch, it overrides the default reference directory which origen uses,
  therefore essentially allowing origen to diff between your output directory and any directory
  of your choice (for example ASCII UTIL export directory)
*********************************************************************************************
END
# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-EOT
The reverse of 'origen compile' to help merge any changes made to compiled files back to the source.
The arguments are the same as the compile command, so run the merge with the same arguments and it will merge instead of compile.
Changes are processed as follows:
* Any files with a non-erb source are simply copied back if they have changes.
* Any files that don't have a source copy are ignored.
* Any differences in files with an ERB source are left to the user to resolve. Origen tries to help by giving you the
  commands to execute to show the differences and the files that must be edited.

Usage: origen merge [space separated files, lists or directories] [options]
  EOT
  opts.on('-t', '--target NAME', String, 'Override the default target, NAME can be a full path or a fragment of a target file name') { |t| options[:target] = t }
  opts.on('-c', '--continue', 'Continue on error (to the next file)') { options[:continue] = true }
  opts.on('-m', '--mode MODE', Origen::Mode::MODES, 'Force the Origen operating mode:', '  ' + Origen::Mode::MODES.join(', ')) { |_m| }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-f', '--file FILE', String, 'Override the default log file') { |o| options[:log_file] = o }
  opts.on('-o', '--output DIR', String, 'Override the default output directory') { |o| options[:output] = o }
  opts.on('-r', '--reference DIR', String, 'Override the default reference directory') { |o| options[:reference] = o }
  app_options.each do |app_option|
    opts.on(*app_option) {}
  end
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit 0 }
end

opt_parser.parse! ARGV
options[:patterns] = ARGV
options[:job_type] = :merge  # To let the generator know a merge job has been requested

Origen.load_application
Origen.target.temporary = options[:target] if options[:target]
Origen.app.load_target!

Origen.app.runner.generate(options)

exit 0
