require 'rspec/core/formatters/base_formatter'

class RGenFormatter < RSpec::Core::Formatters::BaseFormatter

  def dump_summary(duration, example_count, failure_count, pending_count)
    if failure_count > 0
      RGen.app.stats.report_fail
    else
      RGen.app.stats.report_pass
    end
    super(duration, example_count, failure_count, pending_count)
  end

end
