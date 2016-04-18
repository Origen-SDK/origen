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

      # IP block that is associate with this errata
      attr_accessor :ip_block

      # Software workaround object associated with erratum
      attr_accessor :sw_workaround

      def initialize(id, ip_block, overview  = {}, status = {}, sw_workaround = {})
	@id = id
        @ip_block = ip_block
	@title = overview[:title]
	@description = overview[:description]
        @hw_workaround_description = overview[:hw_workaround_description]
        @disposition = status[:disposition]
        @impact = status[:impact]
        @fix_plan = status[:fix_plan]
	@sw_workaround = sw_workaround
      end

    end
  end
end
