require 'active_support/concern'
module RGen
  module Parameters
    extend ActiveSupport::Concern
    autoload :Set, 'rgen/parameters/set'
    autoload :Live, 'rgen/parameters/live'
    autoload :Missing, 'rgen/parameters/missing'

    attr_accessor :current

    module ClassMethods
      def parameters_context(obj = nil)
        if obj
          if obj.is_a?(Symbol)
            valid = [:top, :dut].include?(obj)
          end
          valid ||= obj.is_a?(String)
          unless valid
            fail 'Invalid parameters context, must be :top or a string path to a model object'
          end
          @parameters_context = obj
        else
          @parameters_context
        end
      end
    end

    def define_params(name, options = {}, &block)
      if _parameter_sets[name]
        fail 'Parameter sets cannot be re-opened once originally defined!'
      else
        _parameter_sets[name] = Set.new(top_level: true, owner: self)
        if options[:inherit]
          _validate_parameter_set_name(options[:inherit])
          parent = _parameter_sets[options[:inherit]]
          _parameter_sets[name].copy_defaults_from(parent)
          _parameter_sets[name].define(parent, &block)
        else
          _parameter_sets[name].define(&block)
        end
      end
    end
    alias_method :define_parameters, :define_params

    def with_params(name, _options = {})
      orig = _parameter_current
      self.params = name
      yield
      self.params = orig
    end

    def params
      @_live_parameter_requested = false
      _parameter_sets[_parameter_current] || Missing.new(owner: self)
    end
    alias_method :parameters, :params

    def params=(name)
      # Don't validate on setting this as this object could be used to set
      # the context on some other object, therefore validate later if someone tries
      # to access the params on this object
      # _validate_parameter_set_name(name)
      @_parameter_current = name
    end
    alias_method :parameters=, :params=

    # @api private
    def _parameter_current
      if path = self.class.parameters_context
        case path
        when :top, :dut
          RGen.top_level._parameter_current
        else
          eval(path)._parameter_current
        end
      else
        @_parameter_current || :default
      end
    end

    # @api private
    def _parameter_sets
      @_parameter_sets ||= {}
    end

    # @api private
    def _request_live_parameter
      @_live_parameter_requested = true
    end

    # @api private
    def _live_parameter_requested?
      @_live_parameter_requested
    end

    private

    def _validate_parameter_set_name(name)
      unless _parameter_sets.key?(name)
        puts "Unknown parameter set :#{name} requested for #{self.class}, these are the valid sets:"
        _parameter_sets.keys.each { |k| puts "  :#{k}" }
        puts ''
        fail 'Unknown parameter set!'
      end
    end
  end
end
