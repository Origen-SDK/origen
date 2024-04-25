module Origen
  # Represents an SoC DFT/Operating mode - e.g. SCAN, RAMBIST, etc.
  class ChipMode
    attr_accessor :brief_description
    attr_accessor :description
    attr_writer :name
    attr_writer :data_rate
    attr_accessor :data_rate_unit
    attr_accessor :minimum_version_enabled

    alias_writer :min_ver_enabled, :minimum_version_enabled
    alias_writer :min_version_enabled, :minimum_version_enabled
    attr_accessor :audience

    alias_writer :full_name, :name
    # Returns the object that owns the mode (the SoC instance usually)
    attr_accessor :owner
    attr_accessor :typical_voltage
    alias_method :typ_voltage, :typical_voltage

    def initialize(name, options = {})
      options.each { |k, v| instance_variable_set("@#{k}", v) }
      (block.arity < 1 ? (instance_eval(&block)) : block.call(self)) if block_given?
      @name = name
      validate_args
    end

    def name
      @name || @id
    end
    alias_method :full_name, :name

    def id
      @id || name.to_s.downcase.gsub(/(\s|-)+/, '_').to_sym
    end

    def id=(val)
      @id = val.to_s.gsub(/(\s|-)+/, '_').downcase.to_sym
    end

    def data_rate(options = {})
      options = {
        absolute_number: true
      }.update(options)
      # Convert the data rate to a number
      if !!@data_rate && !!@data_rate_unit
        if options[:absolute_number]
          # The data rate unit was validated on init so it is good to go
          # in theory but should still check if it returns a numeric
          value = @data_rate.send(@data_rate_unit.to_sym)
          if value.is_a?(Numeric)
            value
          else
            Origen.log.error "@data_rate '#{@data_rate}' conversion using @data_rate_unit '#{@data_rate_unit}' did not product a Numeric, exiting..."
          end
        else
          @data_rate
        end
      else
        @data_rate
      end
    end

    def respond_to_missing?(method_name, _include_private = false)
      method_name[-1] == '?'
    end

    # Implements methods like:
    #
    #     if $dut.mode.rambist?
    def method_missing(method_name, *arguments, &block)
      ivar = "@#{method_name.to_s.gsub('=', '')}"
      ivar_sym = ":#{ivar}"
      if method_name[-1] == '?'
        return id == method_name[0..-2].to_sym
      elsif method_name[-1] == '='
        define_singleton_method(method_name) do |val|
          instance_variable_set(ivar, val)
        end
      elsif instance_variables.include? ivar_sym
        instance_variable_get(ivar)
      else
        define_singleton_method(method_name) do
          instance_variable_get(ivar)
        end
      end

      send(method_name, *arguments, &block)
    end

    def to_s
      id.to_s
    end

    def to_sym
      to_s.to_sym
    end

    private

    def validate_args
      unless @data_rate_unit.nil? || @data_rate_unit =~ /n\/a/i || @data_rate_unit =~ /na/i
        # Remove special chars
        ['/', '-'].each do |special_char|
          @data_rate_unit.gsub!(special_char, '')
        end
        # Check if @data_rate_unit is found in the Numeric core_ext lib
        fail "@data_rate_unit '#{@data_rate_unit}' is not an accepted unit" unless 1.send(@data_rate_unit.to_sym)
        # Cannot use @data_rate_unit without @data_rate
        fail '@data_rate_unit must be set with @data_rate, exiting...' if @data_rate.nil?
      end
      unless @data_rate.to_s.nil? || @data_rate.to_s =~ /n\/a/i || @data_rate.to_s =~ /na/i
        # Check if the data rate was passed as a String, if so convert it to a number
        if @data_rate.is_a? String
          if @data_rate.numeric?
            @data_rate = @data_rate.to_numeric
          else
            fail "@data_rate '#{@data_rate}' cannot be converted to a number, exiting..."
          end
        end
      end
      unless @typical_voltage.nil?
        if @typical_voltage.is_a? String
          if @typical_voltage.numeric?
            @typical_voltage = @typical_voltage.to_numeric
          else
            fail "@typical_voltage '#{@typical_voltage}' cannot be converted to a number, exiting..."
          end
        end
      end
    end
  end
end
