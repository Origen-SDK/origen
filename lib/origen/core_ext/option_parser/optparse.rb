require 'optparse'
class OptionParser
  alias_method :orig_parse!, :parse!
  # Extend this method to save all original options so that they can
  # be later appended to any LSF submissions
  def parse!(*args)
    lsf_options = ARGV.dup
    orig_parse!(*args)
    lsf_options -= ARGV  # Now contains all original options

    # Pick whether we should be using the application's LSF instance or Origen's
    # global LSF instance
    if Origen.running_globally?
      Origen.lsf_manager.command_options = lsf_options
    else
      Origen.app.lsf_manager.command_options = lsf_options
    end
  end
end
