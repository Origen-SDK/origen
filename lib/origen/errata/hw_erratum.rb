module Origen
  module Errata
    class HwErratum < BaseErratum

      def initialize(hw_workaround_description, disposition, impact, fix_plan, affected_items, options = {})
        @hw_workaround_description = hw_workaround_description
        @disposition = disposition
        @impact = impact
        @fix_plan = fix_plan
        @affected_items = affected_items
      end

    end
  end
end
