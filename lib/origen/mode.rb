module Origen
  # A class to handle the Origen execution mode
  class Mode
    MODES = [:production, :debug, :simulation]

    def initialize(_options = {})
      @current_mode = :production
    end

    # When called any future changes to the mode will be ignored
    def freeze
      @frozen = true
    end

    def unfreeze
      @frozen = false
    end

    def set(val)
      @current_mode = find_mode(val) unless @frozen
    end

    def to_s
      @current_mode ? @current_mode.to_s : ''
    end

    def find_mode(name)
      name = name.to_s.downcase.to_sym
      if MODES.include?(name)
        name
      else
        mode = MODES.find do |m|
          m.to_s =~ /^#{name}/
        end
        if mode
          mode
        else
          fail "Invalid mode requested, must be one of: #{MODES}"
        end
      end
    end

    # Any mode which is not production will return true here, if
    # you want to test for only debug mode use Origen.mode == :debug
    def debug?
      !production?
    end

    def production?
      @current_mode == :production
    end

    def simulation?
      @current_mode == :simulation
    end

    def ==(val)
      if val.is_a?(Symbol)
        @current_mode == val
      else
        super
      end
    end
  end
end
