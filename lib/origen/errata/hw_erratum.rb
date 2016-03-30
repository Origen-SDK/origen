module Origen
  module Errata
    class HwErratum < BaseErratum

      attr_accessor :hw_workaround_description, :disposition, :impact, :fix_plan, :affected_items
      def initialize(id, title, description, hw_workaround_description, disposition, impact, fix_plan, affected_items, options = {})
        super(id, type = "hw", title, description)
        @hw_workaround_description = hw_workaround_description
        @disposition = disposition
        @impact = impact
        @fix_plan = fix_plan
        @affected_items = affected_items
      end

    end
  end
end
