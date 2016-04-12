module Origen
  module Errata
    class SwErratumWorkaround
  
      # ID number used to identify software workaround
      attr_reader :id

      # Title of software workaround
      attr_accessor :title

      # Description of software workaround and implementation
      attr_accessor :description

      # Availability of workaround, ex:
      #    -- Not Applicable: Errata does not affect software
      #    -- Not Available: Workaround not available
      #    -- Available: Workaround is available to be distributed
      attr_accessor :sw_disposition

      # Software distribution version which incorporates the workaround
      attr_accessor :distribution

      # Release note
      attr_accessor :note

      # Link to patch(s) for workaround
      attr_accessor :patches

      def initialize(id, overview = {}, resolution = {})
	@id = id
	@title = overview[:title]
	@description = overview[:description]
        @sw_disposition = overview[:sw_disposition]
        @distribution = overivew[:distribution]
        @note = resolution[:note]
        @patches = resolution[:patches]
      end
    end
  end

