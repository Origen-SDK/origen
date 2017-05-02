module Origen
  module Pins
    module Timing
      class Timeset
        attr_reader :id

        # Returns an array containing the defined waves for drive cycles.
        # The wave at position 0 will be applied be default to any pin which
        # does not otherwise have a specific wave assignment.
        attr_reader :drive_waves

        # Returns an array containing the defined waves for compare cycles
        # The wave at position 0 will be applied be default to any pin which
        # does not otherwise have a specific wave assignment.
        attr_reader :compare_waves

        def initialize(id)
          @id = id
          @drive_waves = []
          @compare_waves = []
          # Look up tables that map pins to waves
          @compare_pin_map = {}
          @drive_pin_map = {}
          # Temporary storage of pin assignments
          @pin_ids = { drive: [], compare: [] }

          # Create the default waves, these can be overridden later
          wave do |w|
            w.compare :data, at: 'period / 2'
          end

          wave do |w|
            w.drive :data, at: 0
          end
        end

        # Add a new drive or compare wave to the timeset
        #
        #   timeset.wave :tck do |w|
        #     w.drive :data, at: 0
        #     w.drive 0, at: 25
        #     w.dont_care at: "period - 10"
        #   end
        def wave(*pin_ids)
          options = pin_ids.last.is_a?(Hash) ? pin_ids.pop : {}
          w = Wave.new(self, options)
          yield w
          if w.drive?
            if pin_ids.empty?
              w.send(:index=, 0)
              drive_waves[0] = w
              @pin_ids[:drive][0] = pin_ids
            else
              w.send(:index=, drive_waves.size)
              drive_waves << w
              @pin_ids[:drive] << pin_ids
            end
          else
            if pin_ids.empty?
              w.send(:index=, 0)
              compare_waves[0] = w
              @pin_ids[:compare][0] = pin_ids
            else
              w.send(:index=, compare_waves.size)
              compare_waves << w
              @pin_ids[:compare] << pin_ids
            end
          end
        end
        alias_method :compare_wave, :wave
        alias_method :drive_wave, :wave

        # The timeset will cache a view of the dut's pins for performance,
        # calling this method will clear that cache and regenerate the internal
        # view. This should generally not be required, but available for corner cases
        # where a pin is added to the dut after the cache has been generated.
        def clear_cache
          @all_pin_ids = nil
          @groups = nil
          compare_waves.each { |w| w.send(:clear_cache) }
          drive_waves.each { |w| w.send(:clear_cache) }
        end

        private

        # The pin assignments are done lazily to cater for the guy who will want
        # to define waves ahead of pins or some such
        def assign_pins
          @pin_ids[:drive].each_with_index do |ids, i|
            expand_groups(ids) do |id|
              @drive_pin_map[id] ||= []
              @drive_pin_map[id] << i
            end
          end
          @pin_ids[:compare].each_with_index do |ids, i|
            expand_groups(ids) do |id|
              @compare_pin_map[id] ||= []
              @compare_pin_map[id] << i
            end
          end
          @pin_ids = :done
        end

        def expand_groups(ids)
          ids.each do |id|
            if g = dut.pin_groups[id]
              g.each do |pin|
                yield pin.id
              end
            else
              yield id
            end
          end
        end

        def wave_for(pin, options)
          assign_pins unless @pin_ids == :done
          if options[:type] == :drive
            i = @drive_pin_map[pin.id]
            if i
              if i.size > 1
                code = options[:code]
                code = nil if code == 1
                code = nil if code == 0
                i.each do |ix|
                  return drive_waves[ix] if drive_waves[ix].code == code
                end
              else
                drive_waves[i[0]]
              end
            else
              drive_waves[0]
            end
          else
            i = @compare_pin_map[pin.id]
            if i
              if i.size > 1
                code = options[:code]
                code = nil if code == 'L' || code == :L
                code = nil if code == 'H' || code == :H
                i.each do |ix|
                  return drive_waves[ix] if drive_waves[ix].code == code
                end
              else
                compare_waves[i[0]]
              end
            else
              compare_waves[0]
            end
          end
        end

        def pin_ids_for(wave)
          assign_pins unless @pin_ids == :done
          map = wave.drive? ? @drive_pin_map : @compare_pin_map
          if wave.index == 0
            all_pin_ids.select { |id| !map[id] || map[id].include?(0) }
          else
            all_pin_ids.select { |id| map[id] && map[id].include?(wave.index) }
          end
        end

        def all_pin_ids
          @all_pin_ids ||= dut.pins.values.map(&:id)
        end
      end
    end
  end
end
