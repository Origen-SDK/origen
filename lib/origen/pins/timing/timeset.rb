module Origen
  module Pins
    module Timing
      class Timeset
        attr_reader :id

        def initialize(id)
          @id = id
          @drive_waves = []
          @compare_waves = []
        end

        def wave(*pin_ids)
          yield Wave.new
        end
      end
    end
  end
end
