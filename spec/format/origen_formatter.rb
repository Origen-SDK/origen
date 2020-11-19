require 'rspec/core/formatters/base_formatter'

class OrigenFormatter < RSpec::Core::Formatters::BaseFormatter
  rspec_version = RSpec.constants.include?(:Version) ? RSpec::Version::STRING : RSpec::Core::Version::STRING 
  if Gem::Version.new(rspec_version) < Gem::Version.new('3.0.0')
    # legacy formatter
    def dump_summary(duration, example_count, failure_count, pending_count)
      if failure_count > 0
        Origen.app.stats.report_fail
      else
        Origen.app.stats.report_pass
      end
      super(duration, example_count, failure_count, pending_count)
    end
  else
    # RSpec 3 API
    RSpec::Core::Formatters.register self, :dump_summary
    def dump_summary(summary)
      puts
      if summary.failed_examples.size > 0
        Origen.app.stats.report_fail
      else
        Origen.app.stats.report_pass
      end
    end
  end
end
