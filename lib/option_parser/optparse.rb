require 'optparse'
class OptionParser
  alias_method :orig_parse!, :parse!
  # Extend this method to save all original options so that they can
  # be later appended to any LSF submissions
  def parse!(*args)
    lsf_options = ARGV.dup
    orig_parse!(*args)
    lsf_options -= ARGV  # Now contains all original options
    Origen.app.lsf_manager.command_options = lsf_options
  end
end
