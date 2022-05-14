module Origen
  module Utility
    # Collection of methods related to time and dates
    module TimeAndDate
      # Returns the current time in this format:
      # 05-Jun-2010 10:05AM
      def time_now(options = {})
        options = { underscore:   false,
                    format:       :human,
                    include_time: true }.merge(options)

        # Nice description of time format options
        # http://wesgarrison.us/2006/03/12/ruby-strftime-options-for-date-formatting/

        if options[:format] == :human
          Time.now.strftime('%d-%b-%Y %H:%M%p')
        elsif options[:format] == :universal
          time = options[:underscore] ? Time.now.strftime('_%H_%M') : Time.now.strftime('%H%M')
          date = options[:underscore] ? Time.now.strftime('%Y_%m_%d') : Time.now.strftime('%Y%m%d')
          options[:include_time] ? date + time : date
        elsif options[:format] == :timestamp
          Time.now.strftime('%Y%m%d%H%M%S')
        else
          fail 'Unknown date format requested!'
        end
      end
    end
  end
end
