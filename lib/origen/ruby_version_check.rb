require 'pathname'

def ruby_acceptable_to_run?
  RUBY_VERSION >= min_ruby_version
end

def min_ruby_version
  if Origen.os.windows?
    '1.9.3'
  else
    '2.1.0'
  end
end

unless ruby_acceptable_to_run?
  puts <<-END

  You are currently running Ruby version #{RUBY_VERSION}, however Origen supports a minimum version of #{min_ruby_version}.

  END
end
