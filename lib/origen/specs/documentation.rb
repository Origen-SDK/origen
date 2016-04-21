module Origen
  module Specs
    # This class is used to store documentation map that the user can change
    class Documentation
      # Level that Section is at.  Allows for a key to be found.
      attr_accessor :level

      # This is the Section Header for the Documentation Map.  Usually these are main headers
      # Examples:
      #  I. Overall DC Electricals
      #  II. General AC Charactertistics
      #  III. Power Sequencing
      attr_accessor :section

      # This is the subsection header for the Documentation Map.  These are found under main headers
      # Examples
      #  I. Overall DC electrical
      #    A. Absolute Maximum Ratings
      #    B. Recommend Operating Conditions
      #    C. Output Driver
      attr_accessor :subsection

      # Exhibit References that should be referenced within the table title
      attr_accessor :interface

      # Mode is part of the 4-D Hash for the Tables.  Corresponds to Spec 4-D Hash
      attr_accessor :mode

      # Type is part of the 4-D Hash for the Tables.  Corresponds to Spec 4-D Hash
      # Usual values
      #
      # * DC -> Direct Current
      # * AC -> Alternate Current
      # * Temp -> Temperature
      # * Supply -> Supply
      attr_accessor :type

      # SubType is part of the 4-D Hash for the Tables. Corresponds to Spec 4-D Hash
      attr_accessor :sub_type

      # Audience is part of the 4-D Hash for the Tables.  Corresponds to Spec 4-D Hash
      attr_accessor :audience

      # DITA Formatted Text that appears before the table
      attr_accessor :link

      # Initialize the Class
      def initialize(header_info = {}, selection = {}, link = nil)
        @level = header_info[:level]
        @section = header_info[:section]
        @subsection = header_info[:subsection]
        @interface = selection[:interface]
        @mode = selection[:mode]
        @type = selection[:type]
        @sub_type = selection[:sub_type]
        @audience = selection[:audience]
        @link = link
      end
    end
  end
end
