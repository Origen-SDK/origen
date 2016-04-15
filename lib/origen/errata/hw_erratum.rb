module Origen
  module Errata
    class HwErratum 

      # ID number used to identify erratum 
      attr_reader :id
   
      # Erratum Title
      attr_accessor :title
  
      # Description of erratum 
      attr_accessor  :description

      # Description of the hardware workaround for the erratum
      attr_accessor :hw_workaround_description

      # How the errata is to be distributed ex:
      #  --Internal Only
      #  --Customer visible
      #  --Other: 3rd party, etc.
      attr_accessor :disposition

      # Impact of erratum to customer
      attr_accessor :impact

      # When/if the erratum will be fixed
      attr_accessor :fix_plan

      # Lists which SoCs or hw blocks are affected by erratum
      attr_accessor :affected_items

      # Software workaround object associated with erratum
      attr_accessor :sw_workaround

      def initialize(id, overview  = {}, status = {}, affected_items = [], sw_workaround = {})
	@id = id
	@title = overview[:title]
	@description = overview[:description]
        @hw_workaround_description = overview[:hw_workaround_description]
        @disposition = status[:disposition]
        @impact = status[:impact]
        @fix_plan = status[:fix_plan]
        @affected_items = affected_items
	@sw_workaround = sw_workaround
      end

    end
  end
end
