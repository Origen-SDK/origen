module Origen
  module Utility
    class Collector
      attr_reader :_hash_
      attr_reader :merge_method

      # Need to keep a seperate methods list so we know what's been added by method missing instead of what's
      # been added either by the hash or by method missing.
      # Only overwriting a value in the block should cause an error. Overriding a value from the hash depends on
      # the merge method's setting.
      attr_reader :_methods_

      def initialize(options = {}, &block)
        @merge_method = options[:merge_method] || :keep_hash
        @fail_on_empty_args = options[:fail_on_empty_args]
        unless [:keep_hash, :keep_block, :fail].include?(@merge_method)
          fail Origen::OrigenError, "Origen::Utility::Collector cannot merge with method :#{@merge_method} (of class #{@merge_method.class}). Known merge methods are :keep_hash (default), :keep_block, or :fail"
        end

        @_hash_ = options.key?(:hash) ? options[:hash].clone : {}
        @_methods_ = []

        if block_given?
          yield self
        end
      end

      # Legacy store method.
      def store
        Origen.log.deprecate 'Collector::store method was used. Please use the Ruby-centric Collector::to_h or Collector::to_hash method instead' \
                             " Called from: #{caller[0]}"
        @_hash_
      end

      def to_hash
        @_hash_
      end
      alias_method :to_h, :to_hash

      def method_missing(method, *args, &_block)
        key = method.to_s.sub('=', '').to_sym

        # Check that the arguments are correct
        if block_given? && !args.empty?
          # raise Origen::OrigenError, "Origen::Utility::Collector detected both the hash and block attempting to set :#{key} (merge_method set to :fail)"
          fail ArgumentError, "Origen::Utility::Collector cannot accept both an argument list and block simultaneously for :#{key}. Please use one or the other."
        elsif block_given?
          val = _block
        elsif args.size == 0
          # Set any empty argument to nil
          val = nil
        elsif args.size > 1
          fail ArgumentError, "Origen::Utility::Collector does not allow method :#{key} more than 1 argument. Received 3 arguments."
        else
          val = args.first
        end

        # Check if we've already added this key via a method
        if _methods_.include?(key)
          fail Origen::OrigenError, "Origen::Utility::Collector does not allow method :#{key} to be set more than a single time. :#{key} is set to #{_hash_[key]}, tried to set it again to #{val}"
        end

        # indicate that we've seen this method, and decide whether or not to add the new value
        _methods_ << key

        # Merge the value (or don't, depending on what is set)
        if merge_method == :keep_block || !_hash_.key?(key)
          _hash_[key] = val
        elsif merge_method == :fail
          fail Origen::OrigenError, "Origen::Utility::Collector detected both the hash and block attempting to set :#{key} (merge_method set to :fail)"
        end
        # store[key] = val if !store.key?(key) || (store.key?(key) && merge_method == :keep_block)

        # Return self instead of the key value to allow for one-line collector statements
        self
      end
    end
  end
end
