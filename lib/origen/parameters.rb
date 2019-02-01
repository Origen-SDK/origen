require 'active_support/concern'
require 'set'
module Origen
  module Parameters
    extend ActiveSupport::Concern
    autoload :Set, 'origen/parameters/set'
    autoload :Live, 'origen/parameters/live'
    autoload :Missing, 'origen/parameters/missing'

    attr_accessor :current

    # @api private
    #
    # Any define_params blocks contained within the given block will be allowed to be re-opened later
    # in the block to override existing parameter settings or to add new ones.
    #
    # This is not allowed normally since already-defined child parameter sets could have referenced the
    # original parameter and they would not reflect the final value after re-opening the parent parameter
    # set.
    #
    # By defining the parameters within this block, Origen will keep track of relationships between parameter
    # sets and any time a parent is changed the definitions of existing children will be re-executed to ensure
    # that they reflect the new values.
    #
    # This is initially intended to support the concept of a app/parameters/application.rb being
    # used to define baseline parameter sets, and then target-specific files can then override them.
    def self.transaction
      start_transaction
      yield
      stop_transaction
    end

    # @api private
    def self.start_transaction
      @transaction_data = {}
      @transaction_open = true
      @transaction_counter ||= 0
      @transaction_counter += 1
    end

    # @api private
    def self.stop_transaction
      @transaction_counter -= 1
      if @transaction_counter == 0
        # Now finalize (freeze) all parameter sets we have just defined, this was deferred at define time due
        # to running within a transaction
        @transaction_data.each do |model, parameter_sets|
          parameter_sets.keys.each do |name|
            model._parameter_sets[name].finalize
          end
        end
        @transaction_data = nil
        @transaction_open = false
      end
    end

    # @api private
    def self.transaction_data
      @transaction_data
    end

    # @api private
    def self.transaction_open
      @transaction_open
    end

    # @api private
    def self.transaction_redefine
      @transaction_redefine
    end

    # @api private
    def self.redefine(model, name)
      @transaction_redefine = true
      model._parameter_sets.delete(name)
      @transaction_data[model][name][:definitions].each { |options, block| model.define_params(name, options, &block) }
      @transaction_data[model][name][:children].each { |model, name| redefine(model, name) }
      @transaction_redefine = false
    end

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

    # @api private
    def define_params_transaction
      Origen::Parameters.transaction_data
    end

    def define_params(name, options = {}, &block)
      name = name.to_sym
      if _parameter_sets[name] && !Origen::Parameters.transaction_open
        fail "Parameter set '#{name}' cannot be re-opened once originally defined!"
      else
        if Origen::Parameters.transaction_open && !Origen::Parameters.transaction_redefine
          define_params_transaction[self] ||= {}
          define_params_transaction[self][name] ||= { children: ::Set[], definitions: [] }
          define_params_transaction[self][name][:definitions] << [options.dup, block]
          redefine_children = define_params_transaction[self][name][:children] if _parameter_sets[name]
        end
        if _parameter_sets[name]
          defaults_already_set = true
        else
          _parameter_sets[name] = Origen::Parameters::Set.new(top_level: true, owner: self)
        end
        if options[:inherit]
          kontext = _validate_parameter_set_name(options[:inherit])
          parent = kontext[:obj]._parameter_sets[kontext[:context]]
          if Origen::Parameters.transaction_open && !Origen::Parameters.transaction_redefine
            define_params_transaction[kontext[:obj]][kontext[:context]][:children] << [self, name]
          end
          _parameter_sets[name].copy_defaults_from(parent) unless defaults_already_set
          _parameter_sets[name].define(parent, &block)
        else
          _parameter_sets[name].define(&block)
        end
        if redefine_children
          redefine_children.each { |model, set_name| Origen::Parameters.redefine(model, set_name) }
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

    # Return value of param if it exists, nil otherwise.
    def param?(name)
      _param = name.to_s =~ /^params./ ? name.to_s : 'params.' + name.to_s
      begin
        val = eval("self.#{_param}")
      rescue
        nil
      else
        val
      end
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
