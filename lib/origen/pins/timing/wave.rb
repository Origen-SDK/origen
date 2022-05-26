module Origen
  module Pins
    module Timing
      class Wave
        attr_reader :events, :timeset, :index
        # Returns the pattern code value associated with the wave. By default this will return nil
        # if no code was given at the time the wave was defined, which means it is the wave that will
        # be applied for the conventional code values of 0, 1, H, L.
        attr_reader :code

        VALID_DRIVE_DATA = [0, 1, :data]
        VALID_COMPARE_DATA = [0, 1, :data]

        def initialize(timeset, options = {})
          @code = options[:code]
          @code = nil if [0, 1, 'H', 'L', :H, :L].include?(@code)
          @timeset = timeset
          @events = []
        end

        # Returns the events array but with any formula based times
        # evaluated.
        # Note that this does not raise an error if the period is not currently
        # set, in that case any events that reference it will have nil for
        # their time.
        def evaluated_events
          if dut.current_timeset_period
            events.map { |e| [calc.evaluate(e[0], period: dut.current_timeset_period).ceil, e[1]] }
          else
            fail 'The current timeset period has not been set'
          end
        end

        # Returns an array containing all dut pin_ids that
        # are assigned to this wave by the parent timeset
        def pin_ids
          @pins_ids ||= timeset.send(:pin_ids_for, self)
        end

        # Returns an array containing all dut pin objects that
        # are assigned to this wave by the parent timeset
        def pins
          @pins ||= pin_ids.map { |id| dut.pin(id) }
        end

        def drive(data, options)
          self.type = :drive
          validate_data(data) do |d|
            validate_time(options) do |t|
              events << [t, d]
            end
          end
        end

        def compare(data, options)
          self.type = :compare
          validate_data(data) do |d|
            validate_time(options) do |t|
              events << [t, d]
            end
          end
        end
        alias_method :compare_edge, :compare

        def dont_care(options)
          self.type = :drive
          validate_time(options) do |t|
            events << [t, :x]
          end
        end
        alias_method :highz, :dont_care

        def type
          @type ||= :drive
        end

        def drive?
          @type == :drive
        end

        def compare?
          @type == :compare
        end

        private

        def clear_cache
          @pin_ids = nil
          @pins = nil
        end

        def index=(val)
          @index = val
        end

        def validate_data(data)
          valid = drive? ? VALID_DRIVE_DATA : VALID_COMPARE_DATA
          data = :data if :data == :pattern
          unless valid.include?(data)
            fail "Uknown data value #{data}, only these are valid: #{valid.join(', ')}"
          end

          yield data
        end

        def calc
          return @calc if @calc

          require 'dentaku'
          @calc = Dentaku::Calculator.new
        end

        def type=(t)
          if @type
            if @type != t
              fail 'Timing waves cannot both drive and compare within a cycle period!'
            end
          else
            @type = t
          end
        end

        def validate_time(options)
          unless options[:at]
            fail 'When defining a wave event you must supply the time via the option :at'
          end

          t = options[:at]

          if t.is_a?(String)
            d = calc.dependencies(t) - %w(period period_in_ns)
            unless d.empty?
              fail "Wave time formulas can only include the variable 'period' (or 'period_in_ns'), this variable is not allowed: #{d}"
            end

            t = t.gsub('period_in_ns', 'period')
            unless calc.evaluate(t, period: 100)
              fail "There appears to be an error in the formula: #{t}"
            end

            yield t
            return
          elsif t.is_a?(Numeric)
            yield t
            return
          end
          fail 'The :at option in a wave event definition must be either a number or a string'
        end
      end
    end
  end
end
