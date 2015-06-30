require 'pathname'

def ruby_acceptable_to_run?
  RUBY_VERSION >= min_ruby_version
end

def min_ruby_version
  if RUBY_PLATFORM == 'i386-mingw32'
    '1.9.3'
  else
    '2.0.0'
  end
end

unless ruby_acceptable_to_run?
  puts <<-END

  You are currently running Ruby version #{RUBY_VERSION}, however Origen needs version #{min_ruby_version}.

  END
end
