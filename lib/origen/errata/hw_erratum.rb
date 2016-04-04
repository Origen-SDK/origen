module Origen
  module Errata
    class HwErratum 

      attr_accessor :id, :title, :description, :hw_workaround_description, :disposition, :impact, :fix_plan, :affected_items, :sw_workaround
      def initialize(id, options = {})
	@id = id
	@title = options[:title]
	@description = options[:description]
        @hw_workaround_description = options[:hw_workaround_description]
        @disposition = options[:disposition]
        @impact = options[:impact]
        @fix_plan = options[:fix_plan]
        @affected_items = options[:affected_items]
	@sw_workaround = options[:sw_workaround]
      end

    end
  end
end
