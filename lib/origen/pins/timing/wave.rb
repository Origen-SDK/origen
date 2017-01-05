module Origen
  module Pins
    module Timing
      class Wave
        attr_reader :events

        VALID_DRIVE_DATA = [0, 1, :data]
        VALID_COMPARE_DATA = [0, 1, :data]

        def initialize
          @events = []
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
        alias :compare_edge :compare

        def dont_care(*args)
        end
        alias :highz :dont_care

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

        def validate_data(data)
          valid = drive? ? VALID_DRIVE_DATA : VALID_COMPARE_DATA
          data = :data if :data == :pattern
          unless valid.include?(data)
            fail "Uknown data value #{data}, only these are valid: #{valid.join(", ")}"
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
              fail "Timing waves cannot both drive and compare within a cycle period!"
            end
          else
            @type = t
          end
        end

        def validate_time(options)
          unless options[:at]
            fail "When defining a wave event you must supply the time via the option :at"
          end
          t = options[:at]

          if t.is_a?(String)
            d = calc.dependencies(t) - ["period", "period_in_ns"]
            if !d.empty?
              fail "Wave time formulas can only include the variable 'period' (or 'period_in_ns'), this variable is not allowed: #{d}"
            end
            t = t.gsub("period_in_ns", "period")
            unless calc.evaluate(t, period: 100)
              fail "There appears to be an error in the formula: #{t}"
            end
            yield t
            return
          elsif t.is_a?(Numeric)
            yield t
            return
          end
          fail "The :at option in a wave event definition must be either a number or a string"
        end
      end
    end
  end
end
