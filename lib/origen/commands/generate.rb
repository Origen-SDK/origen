require 'optparse'
require 'origen/commands/helpers'

include CommandHelpers

options = {}

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: origen g [space separated patterns or lists] [options]'
  opts.on('-e', '--environment NAME', String, 'Override the default environment, NAME can be a full path or a fragment of an environment file name') { |e| options[:environment] = e }
  opts.on('-t', '--target NAME', String, 'Override the default target, NAME can be a full path or a fragment of a target file name') { |t| options[:target] = t }
  opts.on('-l', '--lsf [ACTION]', [:clear, :add], "Submit jobs to the LSF, optionally specify whether to 'clear' or 'add' to existing jobs") { |a| options[:lsf] = true; options[:lsf_action] = a }
  opts.on('-w', '--wait', 'Wait for LSF processing to complete') { options[:wait_for_lsf_completion] = true }
  opts.on('-c', '--continue', 'Continue on error (to the next pattern)') { options[:continue] = true }
  opts.on('-pl', '--plugin PLUGIN_NAME', String, 'Set current plugin') { |pl_n|  options[:current_plugin] = pl_n }
  opts.on('-f', '--file FILE', String, 'Override the default log file') { |o| options[:log_file] = o }
  opts.on('-o', '--output DIR', String, 'Override the default output directory') { |o| options[:output] = o }
  opts.on('-r', '--reference DIR', String, 'Override the default reference directory') { |o| options[:reference] = o }
  opts.on('-q', '--queue NAME', String, 'Specify the LSF queue, default is short') { |o| options[:queue] = o }
  opts.on('-p', '--project NAME', String, 'Specify the LSF project, default is msg.te') { |o| options[:project] = o }
  opts.on('--doc', 'Generate into doc format') { options[:doc] = true }
  opts.on('--html', 'Generate into html format') { options[:html] = true }
  opts.on('--nocom', 'No comments in the generated pattern') { options[:no_comments] = true }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  opts.on('-m', '--mode MODE', Origen::Mode::MODES, 'Force the Origen operating mode:', '  ' + Origen::Mode::MODES.join(', ')) { |_m| }
  # Apply any application option extensions to the OptionParser
  extend_options(opts, app_options, options)
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit }
end

opt_parser.parse! ARGV
options[:patterns] = ARGV

def self._with_doc_tester(options)
  if options[:doc] || options[:html]
    Origen.app.with_doc_tester(options) do
      yield
    end
  else
    yield
  end
end

Origen.load_application

if options[:queue]
  Origen.config.lsf.queue = options.delete(:queue)
end
if options[:project]
  Origen.config.lsf.project = options.delete(:project)
end

_with_doc_tester(options) do
  Origen.app.plugins.temporary = options[:current_plugin] if options[:current_plugin]
  Origen.environment.temporary = options[:environment] if options[:environment]
  Origen.target.temporary = options[:target] if options[:target]
  Origen.app.load_target!  # This initial load is required to apply any configuration
  # options present in the target, it will loaded again before
  # each generate/compile job
  Origen.app.runner.generate(options)

  Origen.lsf.wait_for_completion if options[:wait_for_lsf_completion]
end

#    method_option :vector_comments,    :default => false, :aliases => "-v", :type => :boolean,
#                           :desc => "Add vector and cycle number comments to the pattern, disabled by default to make diff viewing easier"

# === Task: $ origen g [patname/patlist] [options]
# Generate a pattern or list of patterns.
#
# ==== Supplying a pattern name
# Multiple pattern name arguments can be supplied on the command line. The generator is non-strict
# about pre and post-fixes to the pattern names so the following all work; use whichever is most
# convenient:
#
#   origen g prb_ers_mas_atuf
#   origen g prb_ers_mas_atuf.rb
#   origen g nvm_prb_ers_mas_atuf.atp
#   origen g pattern/erase/prb_ers_mas_atuf.rb
#
# For patterns that use iterators you can supply either the pattern source name or the generated name,
# for example these are equivalent:
#
#   origen g prb_ers_mas_bx.rb
#   origen g prb_ers_mas_b0.atp
#
# Multiple patterns can be supplied on the command line and should be comma separated with no spaces
# in between:
#
#   origen g prb_ers_mas_atuf,prb_ers_mas_bx
#
# A pattern list is simply the name of any file that resides in the /list directory and which contains
# a list of patname arguments (same rules apply as for the command line version).
# The list files can be commented with '#' and can reference other list files. For example it is
# common to make a production.list or master.list file that references other sub lists: probe.list,
# ft.list, etc.
#
# ==== Generator output
# The command line output is as follows:
#
#   Generating... nvm_prb_ers_mas_atuf.atp            3039      0.201732
#                           |                          |            |
#       Created output file, can be found in       Number of   Execution time
#                  output/<soc>/                    vectors     on the tester
#
# All output from the last run can be found in log.txt, this is just a direct copy of the output in
# the console.
#
# ==== Tracking changes
# Upon completion you will be alerted if there are some new or changed files and will prompted to
# save these. It is recommended that you perform the save if you know why the change happened (or if
# you are running in a brand new workspace). You can then use the automatic pattern diff feature to
# be alerted to any change in the pattern content the next time you generate a given pattern. Note that
# a tkdiff executable is automatically output to allow you to inspect the differences.
#
# To allow you to locate changed or new patterns easily they are automatically copied to:
# output/<soc>/changed/
#
# The reference files are stored in $ORIGEN_WORK/.ref <br>
# Very often you will want to compare the output of the current generator to a previous version,
# to do this remove the .ref and replace it with a link to the .ref in another workspace.
#   rm -fr .ref
#   ln -s <path_to_my_ref_workspace>/.ref .ref
# After that generate and save the patterns in the reference workspace and re-run the patterns in the original
# workspace to see if there are any differences.
#
# ==== Options
# For a list of options run:
#   origen help g
