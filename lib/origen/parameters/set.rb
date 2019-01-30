module Origen
  module Parameters
    class Set < Hash
      attr_accessor :top_level
      attr_accessor :name
      attr_accessor :path

      # Allow these parameter names to be valid. When used, they will override the
      # methods of the same name provided by the Hash class.
      OVERRIDE_HASH_METHODS = [:min, :max]

      def initialize(options = {})
        if options[:top_level]
          @top_level = self
          @path = ''
          @owner = options[:owner]
        end
      end

      def define(parent = nil, &_block)
        @defining = true
        yield self, parent
        @defining = false
        finalize
      end

      # Returns the current parameter context
      def context
        owner._parameter_current
      end
      alias_method :current_context, :context

      def available_contexts
        owner._parameter_sets.keys
      end
      alias_method :contexts, :available_contexts

      def copy_defaults_from(set)
        set.each do |name, val|
          if val.is_a?(Set)
            self[name] = new_subset(name)
            self[name].copy_defaults_from(val)
          else
            self[name] = val
          end
        end
      end

      def method_missing(method, *args, &block)
        if defining?
          if args.length == 0
            self[method] ||= new_subset(method)
          elsif args.length > 1
            super
          else
            m = method.to_s.sub('=', '').to_sym
            self[m] = args.first
          end
        else
          if args.length != 0
            super
          else
            val = self[method]
            if val.nil?
              super
            else
              if val.is_a?(Set)
                val
              else
                if live?
                  Live.new(owner: owner, path: path, name: method)
                else
                  if val.is_a?(Proc)
                    val.call(*args)
                  else
                    val
                  end
                end
              end
            end
          end
        end
      end

      OVERRIDE_HASH_METHODS.each do |method|
        define_method method do
          if self[method]
            method_missing(method)
          else
            super
          end
        end
      end

      def each
        super do |key, val|
          if val.is_a?(Proc)
            yield key, val.call
          else
            yield key, val
          end
        end
      end

      def [](key)
        val = super
        val.is_a?(Proc) ? val.call : val
      end

      # Test seems to be some kind of reserved word, that doesn't trigger the method_missing,
      # so re-defining it here to allow a param group called 'test'
      def test(*args, &block)
        method_missing(:test, *args, &block)
      end

      def defining?
        if top_level?
          @defining
        else
          top_level.defining?
        end
      end

      def owner
        if top_level?
          @owner
        else
          top_level.owner
        end
      end

      def top_level?
        top_level == self
      end

      def finalize
        freeze
        each { |_name, val| val.finalize if val.is_a? Set }
      end

      def new_subset(name)
        set = Set.new
        set.name = name
        set.top_level = top_level
        if path == ''
          set.path = name.to_s
        else
          set.path = "#{path}.#{name}"
        end
        set
      end

      def live?
        owner._live_parameter_requested?
      end

      def live
        owner._request_live_parameter
        self
      end

      def to_flat_hash(options = {})
        options = {
          delimiter: '.'
        }.update(options)
        flatten_params(self, options[:delimiter]).first
      end

      private

      def flatten_params(param_hash, delimiter, name = nil, results_hash = {})
        param_hash.each do |k, v|
          if v.is_a? Origen::Parameters::Set
            name.nil? ? name = k.to_s : name << "#{delimiter}#{k}"
            (results_hash, name) = flatten_params(v, delimiter, name, results_hash)
          else
            if name.nil?
              results_hash[k] = v
            else
              results_hash["#{name}#{delimiter}#{k}"] = v
              if k == param_hash.keys.last
                name = name.include?(delimiter) ? name.split(delimiter)[0..-2].join(delimiter) : nil
              end
            end
          end
        end
        [results_hash, name]
      end
    end
  end
end
