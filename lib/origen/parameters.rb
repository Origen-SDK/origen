require 'active_support/concern'
module Origen
  module Parameters
    extend ActiveSupport::Concern
    autoload :Set, 'origen/parameters/set'
    autoload :Live, 'origen/parameters/live'
    autoload :Missing, 'origen/parameters/missing'

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
          kontext = _validate_parameter_set_name(options[:inherit])
          parent = kontext[:obj]._parameter_sets[kontext[:context]]
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

    def params(context = nil)
      @_live_parameter_requested = false
      context ||= _parameter_current
      _parameter_sets[context] || Missing.new(owner: self)
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

    def has_params?
      _parameter_sets.empty? ? false : true
    end

    # @api private
    def _parameter_current
      if path = self.class.parameters_context
        case path
        when :top, :dut
          Origen.top_level._parameter_current
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

    def _validate_parameter_set_name(expr)
      # Check if the user specified to inherit from another object
      # or just passed in a param context
      param_context = {}.tap do |context_hash|
        case expr
        when Symbol
          # user specified a local context
          context_hash[:obj] = self
          context_hash[:context] = expr
        when String
          # user specified a DUT path
          path = expr.split('.')[0..-2].join('.')
          kontext = expr.split('.')[-1].to_sym
          context_hash[:obj] = eval(path)
          context_hash[:context] = kontext
        else
          Origen.log.error('Parameter context must be a Symbol (local to self) or a String (reference to another object)!')
          fail
        end
      end
      if param_context[:obj]._parameter_sets.key?(param_context[:context])
        return param_context
      else
        puts "Unknown parameter set :#{param_context[:context]} requested for #{param_context[:obj].class}, these are the valid sets:"
        param_context[:obj]._parameter_sets.keys.each { |k| puts "  :#{k}" }
        puts ''
        fail 'Unknown parameter set!'
      end
    end
  end
end
